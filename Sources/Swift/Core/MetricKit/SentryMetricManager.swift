// MetricManager only exists in the SDKs of Xcode 27 and later.
#if (os(iOS) || os(macOS) || os(visionOS)) && compiler(>=6.4)
internal import _SentryPrivate
import Foundation
import MetricKit

/// Delivers the reports of `MetricManager`, so tests can provide their own reports.
@available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
protocol SentryMetricManagerSource: Sendable {
    func makeDiagnosticReports() -> any AsyncSequence<MetricKit.DiagnosticReport, Never>
    // MetricManager doesn't report metrics on visionOS.
    #if os(iOS) || os(macOS)
    func makeMetricReports() -> any AsyncSequence<MetricKit.MetricReport, Never>
    #endif // os(iOS) || os(macOS)
}

@available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
extension MetricManager: SentryMetricManagerSource {
    func makeDiagnosticReports() -> any AsyncSequence<MetricKit.DiagnosticReport, Never> {
        diagnosticReports
    }

    #if os(iOS) || os(macOS)
    func makeMetricReports() -> any AsyncSequence<MetricKit.MetricReport, Never> {
        metricReports
    }
    #endif // os(iOS) || os(macOS)
}

/// Receives the reports of `MetricManager`, which replaces `MXMetricManager` on xOS 27 and later.
@available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
final class SentryMetricManager: SentryMetricKitReportReceiver {
    private let source: SentryMetricManagerSource
    /// Captures the diagnostic reports, or `nil` when `MetricManager` doesn't deliver diagnostics.
    private let diagnosticCapturer: SentryMXDiagnosticCapturer?
    /// Records the metric reports, or `nil` when `MetricManager` doesn't deliver metrics.
    private let metricRecorder: SentryMXMetricRecorder?
    private let reportTasks = SentryMutex<[Task<Void, Never>]>([])

    /// - Parameter metricRecorder: Ignored on visionOS, where `MetricManager` doesn't report
    ///   metrics.
    init(
        source: SentryMetricManagerSource = MetricManager(),
        diagnosticCapturer: SentryMXDiagnosticCapturer?,
        metricRecorder: SentryMXMetricRecorder?
    ) {
        self.source = source
        self.diagnosticCapturer = diagnosticCapturer
        self.metricRecorder = metricRecorder
    }

    func receiveReports() {
        let source = self.source
        var tasks: [Task<Void, Never>] = []
        if diagnosticCapturer != nil {
            SentrySDKLog.info("Started receiving diagnostic reports from MetricManager")
            tasks.append(Task { [weak self] in
                for await report in source.makeDiagnosticReports() {
                    guard let self, !Task.isCancelled else {
                        return
                    }
                    self.process(diagnosticReport: report)
                }
            })
        }
        #if os(iOS) || os(macOS)
        if metricRecorder != nil {
            SentrySDKLog.info("Started receiving metric reports from MetricManager")
            tasks.append(Task { [weak self] in
                for await report in source.makeMetricReports() {
                    guard let self, !Task.isCancelled else {
                        return
                    }
                    self.process(metricReport: report)
                }
            })
        }
        #endif // os(iOS) || os(macOS)
        replaceReportTasks(with: tasks)
    }

    func pauseReports() {
        SentrySDKLog.info("Paused receiving reports from MetricManager")
        replaceReportTasks(with: [])
    }

    func process(diagnosticReport report: MetricKit.DiagnosticReport) {
        guard let diagnosticCapturer else {
            return
        }
        SentrySDKLog.info("Received MetricKit diagnostic report")
        guard let diagnostic = Self.diagnostic(of: report) else {
            SentrySDKLog.debug("Unsupported MetricKit diagnostic report, skipping it")
            return
        }
        diagnosticCapturer.capture(diagnostic)
    }

    #if os(iOS) || os(macOS)
    func process(metricReport report: MetricKit.MetricReport) {
        metricRecorder?.record(metricReport: report)
    }
    #endif // os(iOS) || os(macOS)

    /// Stores the tasks that iterate the reports and cancels the previous ones.
    private func replaceReportTasks(with tasks: [Task<Void, Never>]) {
        let previousTasks = reportTasks.withLock { current in
            let previousTasks = current
            current = tasks
            return previousTasks
        }
        previousTasks.forEach { $0.cancel() }
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
    }
}

@available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
extension SentryMXDiagnostic.Metadata {
    init(_ environment: MetricKit.DiagnosticReport.Environment) {
        let osVersion = environment.osVersion
        self.init(
            pid: environment.pid.flatMap { $0 == 0 ? nil : $0 },
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
