#if os(iOS) || os(macOS) || os(visionOS)
import Foundation

/// A previous run of the app that ended fatally, as recorded by the SDK.
///
/// MetricKit can deliver the diagnostic of such a run on a later launch. The SDK keeps these
/// records so the diagnostic can be matched to the run and to how the SDK already reported it.
struct SentryMXFatalRun: Codable, Equatable {
    /// How the SDK reported the run.
    enum Report: String, Codable {
        /// The crash handler recorded a crash report.
        case crashHandler
        /// The watchdog termination integration reported the run.
        case watchdogTermination
    }

    /// The random identifier the SDK created when the run started.
    let runId: UUID
    let pid: pid_t
    /// The process start time of the run.
    let start: Date
    /// When the next run started, which is the latest the run can have ended.
    let end: Date
    let report: Report

    /// The time the run's process can have lived.
    var lifetime: DateInterval {
        // Guards against a clock that went backwards between the runs.
        DateInterval(start: start, end: max(start, end))
    }
}

/// What MetricKit reports with a diagnostic that identifies the run that recorded it.
struct SentryMXDiagnosticRun: Equatable {
    /// The run IDs the SDK reported as state while the diagnostic was recorded. Only reported on
    /// iOS and macOS 27 and later.
    let runIds: [UUID]
    /// The process ID of the run, or `nil` when MetricKit doesn't report it.
    let pid: pid_t?
    /// The time range of the payload or report that delivered the diagnostic.
    let timeRange: DateInterval
}

/// Finds the recorded fatal run a MetricKit diagnostic belongs to.
///
/// See decision 41 in `develop-docs/DECISIONS.md`.
enum SentryMXRunMatcher {
    enum Match: Equatable {
        /// The diagnostic belongs to this run.
        case run(SentryMXFatalRun)
        /// The diagnostic doesn't belong to any recorded run.
        case unmatched
        /// The diagnostic can belong to more than one recorded run, so it is treated as unmatched.
        case ambiguous
    }

    static func match(_ diagnostic: SentryMXDiagnosticRun, in runs: [SentryMXFatalRun]) -> Match {
        // A diagnostic that carries the states of several runs can't tell which one recorded it.
        guard Set(diagnostic.runIds).count <= 1 else {
            return .ambiguous
        }
        return single(runs.filter { isCandidate(diagnostic, runId: $0.runId, pid: $0.pid, lifetime: $0.lifetime) })
    }

    /// Whether the diagnostic belongs to a run that isn't recorded as fatal, such as the run
    /// directly before the running process.
    ///
    /// - Parameter end: The latest the run can have ended, which is when the next run started.
    static func matches(_ diagnostic: SentryMXDiagnosticRun, run: SentryMXRunStore.Run, end: Date) -> Bool {
        guard Set(diagnostic.runIds).count <= 1 else {
            return false
        }
        let lifetime = DateInterval(start: run.start, end: max(run.start, end))
        return isCandidate(diagnostic, runId: run.runId, pid: run.pid, lifetime: lifetime)
    }

    /// The run ID is exact, so a diagnostic that carries one isn't matched by its process ID, even
    /// when no run has that ID. Otherwise the OS reuses process IDs, so the diagnostic's time
    /// range must also overlap the lifetime of the run.
    private static func isCandidate(_ diagnostic: SentryMXDiagnosticRun, runId: UUID, pid: pid_t, lifetime: DateInterval) -> Bool {
        if let diagnosticRunId = diagnostic.runIds.first {
            return diagnosticRunId == runId
        }
        guard let diagnosticPid = diagnostic.pid else {
            return false
        }
        return diagnosticPid == pid && lifetime.intersects(diagnostic.timeRange)
    }

    private static func single(_ candidates: [SentryMXFatalRun]) -> Match {
        switch candidates.count {
        case 0:
            return .unmatched
        case 1:
            return .run(candidates[0])
        default:
            return .ambiguous
        }
    }
}

/// The fatal runs the SDK keeps for matching MetricKit diagnostics delivered on later launches.
struct SentryMXFatalRunHistory: Codable, Equatable {
    /// MetricKit delivers diagnostics within days, so older runs can't be matched anymore.
    static let maxAge: TimeInterval = 7 * 24 * 60 * 60
    /// Limits the history of an app that terminates fatally on every launch.
    static let maxCount = 10

    private(set) var runs: [SentryMXFatalRun] = []

    /// Adds a run and removes the runs that are too old to be matched.
    mutating func add(_ run: SentryMXFatalRun, now: Date) {
        runs.append(run)
        prune(now: now)
    }

    mutating func prune(now: Date) {
        runs.removeAll { now.timeIntervalSince($0.end) > Self.maxAge }
        if runs.count > Self.maxCount {
            runs.removeFirst(runs.count - Self.maxCount)
        }
    }

    /// Removes a run once its diagnostic was handled, so a second delivery doesn't match it again.
    mutating func remove(_ run: SentryMXFatalRun) {
        runs.removeAll { $0.runId == run.runId }
    }
}

#endif // os(iOS) || os(macOS) || os(visionOS)
