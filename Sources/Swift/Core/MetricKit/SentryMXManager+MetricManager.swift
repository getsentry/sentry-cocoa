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

@available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
extension SentryMXManager {
    func receiveDiagnosticReports(from source: SentryDiagnosticReportSource) {
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

    func pauseDiagnosticReports() {
        replaceDiagnosticReportsTask(with: nil)
    }

    func process(diagnosticReport report: MetricKit.DiagnosticReport) {
        SentrySDKLog.info("Received MetricKit diagnostic report")
        guard let diagnostic = diagnostic(of: report) else {
            SentrySDKLog.debug("Unsupported MetricKit diagnostic report, skipping it")
            return
        }
        capture(diagnostic)
    }

    private func diagnostic(of report: MetricKit.DiagnosticReport) -> SentryMXDiagnostic? {
        switch report.result {
        case .crash(let crash):
            return makeDiagnostic(.crash, callStackTree: crash.callStackTree, of: report, exceptionValue: Self.crashExceptionValue(
                exceptionType: crash.exceptionType.map { String($0) } ?? "nil",
                code: crash.exceptionCode.map { String($0) } ?? "nil",
                signal: crash.signal.map { String($0) } ?? "nil"
            ))
        case .hang(let hang):
            return makeDiagnostic(
                .hang,
                level: Self.hangLevel(hangDuration: hang.hangDuration),
                callStackTree: hang.callStackTree,
                of: report,
                exceptionValue: self.hangExceptionValue(hangDuration: hang.hangDuration)
            )
        case .cpuException(let cpuException):
            return makeDiagnostic(
                .cpuException,
                callStackTree: cpuException.callStackTree,
                of: report,
                exceptionValue: self.cpuExceptionValue(totalCPUTime: cpuException.totalCPUTime, totalSampledTime: cpuException.totalSampledTime)
            )
        case .diskWriteException(let diskWriteException):
            return makeDiagnostic(
                .diskWriteException,
                callStackTree: diskWriteException.callStackTree,
                of: report,
                exceptionValue: self.diskWriteExceptionValue(totalWritesCaused: diskWriteException.totalBytesWritten)
            )
        #if !os(visionOS)
        case .appLaunch(let appLaunch):
            return makeDiagnostic(
                .appLaunch,
                callStackTree: appLaunch.callStackTree,
                of: report,
                exceptionValue: self.appLaunchExceptionValue(launchDuration: appLaunch.launchDuration)
            )
        #endif // !os(visionOS)
        #if os(iOS) && !targetEnvironment(macCatalyst)
        case .memoryException(let memoryException):
            return makeDiagnostic(
                .memoryException,
                callStackTree: memoryException.callStackTree,
                of: report,
                exceptionValue: "The app or extension exceeded its memory limit"
            )
        #endif // os(iOS) && !targetEnvironment(macCatalyst)
        @unknown default:
            return nil
        }
    }

    private func makeDiagnostic(
        _ diagnosticReport: Diagnostic,
        level: SentryLevel? = nil,
        callStackTree: MetricKit.CallStackTree,
        of report: MetricKit.DiagnosticReport,
        exceptionValue: @autoclosure @escaping () -> String
    ) -> SentryMXDiagnostic {
        SentryMXDiagnostic(
            report: diagnosticReport,
            exceptionValue: exceptionValue,
            level: level,
            timestamp: report.timeRange.start,
            metadata: SentryMXDiagnostic.Metadata(report.environment),
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
