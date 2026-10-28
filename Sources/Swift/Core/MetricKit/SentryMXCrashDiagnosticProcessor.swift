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

        return SentryMXDiagnostic(
            report: report,
            exceptionValue: exceptionValue(exceptionType: exceptionType, code: code, signal: signal),
            payloadTimeStampBegin: timestamp,
            diagnostic: diagnostic
        )
    }

    static func exceptionValue(exceptionType: String, code: String, signal: String) -> String {
        "MachException Type:\(exceptionType) Code:\(code) Signal:\(signal)"
    }
}

#if compiler(>=6.4)
@available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
extension SentryMXCrashDiagnosticProcessor {
    static func diagnostic(of crash: MetricKit.CrashDiagnostic, in report: MetricKit.DiagnosticReport) -> SentryMXDiagnostic {
        SentryMXDiagnostic(
            self.report,
            exceptionValue: exceptionValue(
                exceptionType: crash.exceptionType.map { String($0) } ?? "nil",
                code: crash.exceptionCode.map { String($0) } ?? "nil",
                signal: crash.signal.map { String($0) } ?? "nil"
            ),
            callStackTree: crash.callStackTree,
            in: report
        )
    }
}
#endif // compiler(>=6.4)

#endif // os(iOS) || os(macOS) || os(visionOS)
