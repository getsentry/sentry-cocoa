// MetricManager only exists in the SDKs of Xcode 27 and later.
#if (os(iOS) || os(macOS) || os(visionOS)) && compiler(>=6.4)
internal import _SentryPrivate
import Foundation
import MetricKit

/// Delivers the diagnostic reports of `MetricManager`, so tests can provide their own reports.
@available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
protocol SentryDiagnosticReportSource: Sendable {
    func makeDiagnosticReports() -> any AsyncSequence<MetricKit.DiagnosticReport, Never>
}

@available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
extension MetricManager: SentryDiagnosticReportSource {
    func makeDiagnosticReports() -> any AsyncSequence<MetricKit.DiagnosticReport, Never> {
        diagnosticReports
    }
}

/// Receives the diagnostic reports of `MetricManager`, which replaces `MXMetricManager` for
/// diagnostics on xOS 27 and later.
@available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
final class SentryMetricManager: SentryMetricKitReportReceiver {
    private let source: SentryDiagnosticReportSource
    private let diagnosticCapturer: SentryMXDiagnosticCapturer
    private let diagnosticReportsTask = SentryMutex<Task<Void, Never>?>(nil)
    /// Keeps reporting the run ID state, so diagnostics of this run carry it.
    private let runStateReporter: AnyObject?

    init(
        source: SentryDiagnosticReportSource = MetricManager(),
        diagnosticCapturer: SentryMXDiagnosticCapturer,
        runStateReporter: AnyObject? = nil
    ) {
        self.source = source
        self.diagnosticCapturer = diagnosticCapturer
        self.runStateReporter = runStateReporter
    }

    /// Creates the manager that reads the diagnostics of `MetricManager`.
    ///
    /// On iOS and macOS, it reports the SDK's run ID as state and enables the state's domain, so
    /// diagnostics delivered on a later launch can be matched to the run that recorded them. State
    /// reporting is unavailable on visionOS.
    static func make(diagnosticCapturer: SentryMXDiagnosticCapturer, runId: UUID) -> SentryMetricManager {
        #if os(iOS) || os(macOS)
        return SentryMetricManager(
            source: MetricManager(enabledStateReportingDomains: [SentryMXRunState.domain]),
            diagnosticCapturer: diagnosticCapturer,
            runStateReporter: SentryMXRunState.report(runId: runId)
        )
        #else
        return SentryMetricManager(diagnosticCapturer: diagnosticCapturer)
        #endif // os(iOS) || os(macOS)
    }

    func receiveReports() {
        SentrySDKLog.info("Started receiving diagnostic reports from MetricManager")
        let source = self.source
        let task = Task { [weak self] in
            for await report in source.makeDiagnosticReports() {
                guard let self, !Task.isCancelled else {
                    return
                }
                self.process(diagnosticReport: report)
            }
        }
        replaceDiagnosticReportsTask(with: task)
    }

    func pauseReports() {
        SentrySDKLog.info("Paused receiving diagnostic reports from MetricManager")
        replaceDiagnosticReportsTask(with: nil)
    }

    func process(diagnosticReport report: MetricKit.DiagnosticReport) {
        SentrySDKLog.info("Received MetricKit diagnostic report")
        guard let diagnostic = Self.diagnostic(of: report) else {
            SentrySDKLog.debug("Unsupported MetricKit diagnostic report, skipping it")
            return
        }
        diagnosticCapturer.capture(diagnostic)
    }

    /// Stores the task that iterates the diagnostic reports and cancels the previous one.
    private func replaceDiagnosticReportsTask(with task: Task<Void, Never>?) {
        let previousTask = diagnosticReportsTask.withLock { current in
            let previousTask = current
            current = task
            return previousTask
        }
        previousTask?.cancel()
    }

    private static func diagnostic(of report: MetricKit.DiagnosticReport) -> SentryMXDiagnostic? {
        switch report.result {
        case .crash(let crash):
            return SentryMXCrashDiagnosticProcessor.diagnostic(of: crash, in: report)
        case .hang(let hang):
            return SentryMXHangDiagnosticProcessor.diagnostic(of: hang, in: report)
        case .cpuException(let cpuException):
            return SentryMXCPUExceptionDiagnosticProcessor.diagnostic(of: cpuException, in: report)
        case .diskWriteException(let diskWriteException):
            return SentryMXDiskWriteExceptionDiagnosticProcessor.diagnostic(of: diskWriteException, in: report)
        #if !os(visionOS)
        case .appLaunch(let appLaunch):
            return SentryMXAppLaunchDiagnosticProcessor.diagnostic(of: appLaunch, in: report)
        #endif // !os(visionOS)
        #if os(iOS) && !targetEnvironment(macCatalyst)
        case .memoryException(let memoryException):
            return SentryMXMemoryExceptionDiagnosticProcessor.diagnostic(of: memoryException, in: report)
        #endif // os(iOS) && !targetEnvironment(macCatalyst)
        @unknown default:
            return nil
        }
    }
}

@available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
extension SentryMXDiagnostic {
    /// Converts a diagnostic of a `MetricManager` report.
    init(
        _ diagnosticReport: SentryMetricKit.DiagnosticReport,
        exceptionValue: @autoclosure @escaping () -> String,
        level: SentryLevel? = nil,
        callStackTree: MetricKit.CallStackTree,
        in report: MetricKit.DiagnosticReport
    ) {
        self.init(
            report: diagnosticReport,
            exceptionValue: exceptionValue,
            level: level,
            timestamp: report.timeRange.start,
            metadata: Metadata(report.environment),
            callStackTree: {
                try SentryMXCallStackTree(callStackTree)
            },
            rawJSON: {
                do {
                    return try JSONEncoder().encode(report)
                } catch {
                    SentrySDKLog.warning("Failed to encode MetricKit diagnostic report: \(error)")
                    return nil
                }
            },
            rawFilename: "DiagnosticReport.json"
        )
        timeRange = report.timeRange
    }
}

@available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
extension SentryMXDiagnostic.Metadata {
    init(_ environment: MetricKit.DiagnosticReport.Environment) {
        let osVersion = environment.osVersion
        #if os(iOS) || os(macOS)
        let runIds = SentryMXRunState.runIds(in: environment.states)
        #else
        // State reporting is unavailable on visionOS.
        let runIds: [UUID] = []
        #endif // os(iOS) || os(macOS)
        self.init(
            pid: environment.pid.flatMap { $0 == 0 ? nil : $0 },
            runIds: runIds,
            appVersion: environment.applicationVersion,
            appBuild: environment.applicationBuildVersion,
            osVersion: osVersion.number.isEmpty ? nil : osVersion.number,
            osBuild: osVersion.buildNumber.isEmpty ? nil : osVersion.buildNumber
        )
    }
}

/// A call stack frame of `MetricManager` that the SDK can't symbolicate.
struct SentryMXCallStackConversionError: Error, CustomStringConvertible {
    let description: String
}

@available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
extension SentryMXCallStackTree {
    /// Converts the call stack tree of `MetricManager` into the format of the legacy JSON
    /// representation, so both APIs share the stack trace and flame graph handling.
    init(_ tree: MetricKit.CallStackTree) throws {
        self.init(
            callStacks: try tree.callStackThreads.map { thread in
                SentryMXCallStack(
                    threadAttributed: thread.threadAttributed,
                    callStackRootFrames: try thread.rootFrames.map { try SentryMXFrame($0, tree: tree) }
                )
            },
            callStackPerThread: tree.callStackPerThread
        )
    }
}

@available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
extension SentryMXFrame {
    /// Throws like decoding the legacy JSON representation does when a frame has no address,
    /// because such a frame can't be symbolicated.
    init(_ frame: MetricKit.CallStackFrame, tree: MetricKit.CallStackTree) throws {
        guard let address = frame.address else {
            throw SentryMXCallStackConversionError(description: "MetricKit call stack frame has no address")
        }
        guard let offset = frame.offsetIntoBinaryTextSegment, let offsetIntoBinaryTextSegment = Int(exactly: offset) else {
            throw SentryMXCallStackConversionError(description: "MetricKit call stack frame has no valid offset into its binary")
        }
        self.init(
            binaryUUID: frame.binaryUUID,
            offsetIntoBinaryTextSegment: offsetIntoBinaryTextSegment,
            binaryName: frame.binaryName(from: tree),
            address: address,
            subFrames: frame.subFrames.isEmpty ? nil : try frame.subFrames.map { try SentryMXFrame($0, tree: tree) },
            sampleCount: frame.sampleCount
        )
    }
}

#endif // (os(iOS) || os(macOS) || os(visionOS)) && compiler(>=6.4)
