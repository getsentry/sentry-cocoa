#if os(iOS) || os(macOS) || os(visionOS)
import Foundation
import MetricKit

/// Converts MetricKit crash diagnostics.
enum SentryMXCrashDiagnosticProcessor: SentryMXDiagnosticProcessor {
    static let report = SentryMetricKit.DiagnosticReport.crash

    static func diagnostic(of diagnostic: MXCrashDiagnostic, timestamp: Date) -> SentryMXDiagnostic {
        let exceptionType = diagnostic.exceptionType?.stringValue ?? "nil"
        let code = diagnostic.exceptionCode?.stringValue ?? "nil"
        let signal = diagnostic.signal?.stringValue ?? "nil"
        let reason = diagnostic.terminationReason
        let isWatchdog = reason?.localizedCaseInsensitiveContains("0x8badf00d") == true

        return SentryMXDiagnostic(
            report: report,
            exceptionTypeOverride: isWatchdog ? "WatchdogTermination" : nil,
            exceptionValue: exceptionValue(exceptionType: exceptionType, code: code, signal: signal, terminationReason: reason, isWatchdog: isWatchdog),
            payloadTimeStampBegin: timestamp,
            diagnostic: diagnostic
        )
    }

    static func exceptionValue(exceptionType: String, code: String, signal: String, terminationReason: String? = nil, isWatchdog: Bool = false) -> String {
        var value = "MachException Type:\(exceptionType) Code:\(code) Signal:\(signal)"
        
        if let reason = terminationReason, !reason.isEmpty {
            value += " TerminationReason:\(reason)"
        }
        
        if isWatchdog {
            value = "Watchdog Termination - " + value
        }
        
        return value
    }
}

#if compiler(>=6.4)
@available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
extension SentryMXCrashDiagnosticProcessor {
    static func diagnostic(of crash: MetricKit.CrashDiagnostic, in report: MetricKit.DiagnosticReport) -> SentryMXDiagnostic {
        let reasonString = crash.terminationReason?.rawValue
        let isWatchdog = crash.terminationCategory == .watchdog || reasonString?.localizedCaseInsensitiveContains("0x8badf00d") == true
        
        return SentryMXDiagnostic(
            self.report,
            exceptionTypeOverride: isWatchdog ? "WatchdogTermination" : nil,
            exceptionValue: exceptionValue(
                exceptionType: crash.exceptionType.map { String($0) } ?? "nil",
                code: crash.exceptionCode.map { String($0) } ?? "nil",
                signal: crash.signal.map { String($0) } ?? "nil",
                terminationReason: reasonString,
                isWatchdog: isWatchdog
            ),
            callStackTree: crash.callStackTree,
            in: report
        )
    }
}
#endif // compiler(>=6.4)

#endif // os(iOS) || os(macOS) || os(visionOS)
