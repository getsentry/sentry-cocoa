#if os(iOS) || os(macOS) || os(visionOS)
internal import _SentryPrivate
import Foundation

/// Stores the identity of the running process and the fatal runs before it, so MetricKit
/// diagnostics delivered on later launches can be matched to the run that recorded them.
///
/// See decision 41 in `develop-docs/DECISIONS.md`.
final class SentryMXRunStore: SentryPreviousRunRecorder {
    /// The identity of one run of the app.
    struct Run: Codable, Equatable {
        let runId: UUID
        let pid: pid_t
        /// The process start time of the run.
        let start: Date
    }

    private struct Contents: Codable {
        /// The last run that recorded its launch, which is the previous run until the running
        /// process records its own.
        var lastRun: Run?
        /// The run before ``lastRun``.
        var previousRun: Run?
        var fatalRuns = SentryMXFatalRunHistory()
    }

    /// The run ID of the running process. It stays the same when the SDK is started more than once
    /// or the dependency container is reset, because it identifies the process, not an SDK start.
    static let processRunId = UUID()

    let currentRun: Run
    private let path: String
    private let dateProvider: SentryCurrentDateProvider
    private let lock = NSLock()

    init(path: String, currentRun: Run, dateProvider: SentryCurrentDateProvider) {
        self.path = path
        self.currentRun = currentRun
        self.dateProvider = dateProvider
    }

    convenience init(directory: String, sysctl: SentrySysctl, dateProvider: SentryCurrentDateProvider) {
        self.init(
            path: (directory as NSString).appendingPathComponent("metrickit-runs.json"),
            currentRun: Run(
                runId: Self.processRunId,
                pid: ProcessInfo.processInfo.processIdentifier,
                start: sysctl.processStartTimestamp
            ),
            dateProvider: dateProvider
        )
    }

    // MARK: - Recording

    /// Records the launch of the running process, and the previous run when it ended fatally.
    ///
    /// Only the first call of a process records anything, so starting the SDK again in the same
    /// process doesn't treat the running process as the previous run.
    func recordPreviousRun(crashed: Bool, watchdogTerminated: Bool) {
        lock.synchronized {
            var contents = read()
            guard contents.lastRun?.runId != currentRun.runId else {
                return
            }

            let now = dateProvider.date()
            // The crash handler only reports crashes it recorded, and the watchdog termination
            // logic never reports a run the crash handler reported.
            let report: SentryMXFatalRun.Report? = crashed ? .crashHandler : (watchdogTerminated ? .watchdogTermination : nil)
            if let report, let previousRun = contents.lastRun {
                SentrySDKLog.debug("Recording fatal run \(previousRun.runId) reported by \(report.rawValue) for MetricKit")
                contents.fatalRuns.add(
                    SentryMXFatalRun(
                        runId: previousRun.runId,
                        pid: previousRun.pid,
                        start: previousRun.start,
                        // The previous run ended before the running process started.
                        end: currentRun.start,
                        report: report
                    ),
                    now: now
                )
            } else {
                contents.fatalRuns.prune(now: now)
            }
            contents.previousRun = contents.lastRun
            contents.lastRun = currentRun
            write(contents)
        }
    }

    // MARK: - Reading

    /// The recorded fatal runs that MetricKit diagnostics can still belong to.
    var fatalRuns: [SentryMXFatalRun] {
        lock.synchronized {
            var history = read().fatalRuns
            history.prune(now: dateProvider.date())
            return history.runs
        }
    }

    /// The run before the running process, or `nil` when it isn't known.
    var previousRun: Run? {
        lock.synchronized {
            let contents = read()
            // Until the running process records its launch, the last run is the previous run.
            return contents.lastRun?.runId == currentRun.runId ? contents.previousRun : contents.lastRun
        }
    }

    /// Removes a run once its diagnostic was handled, so another delivery doesn't match it again.
    func remove(_ run: SentryMXFatalRun) {
        lock.synchronized {
            var contents = read()
            contents.fatalRuns.remove(run)
            write(contents)
        }
    }

    // MARK: - File

    private func read() -> Contents {
        guard let data = FileManager.default.contents(atPath: path) else {
            return Contents()
        }
        do {
            return try JSONDecoder().decode(Contents.self, from: data)
        } catch {
            SentrySDKLog.warning("Failed to decode the MetricKit runs, starting with none: \(error)")
            return Contents()
        }
    }

    private func write(_ contents: Contents) {
        do {
            let data = try JSONEncoder().encode(contents)
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        } catch {
            SentrySDKLog.warning("Failed to store the MetricKit runs: \(error)")
        }
    }
}

#endif // os(iOS) || os(macOS) || os(visionOS)
