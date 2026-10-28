#if os(iOS) || os(macOS) || os(visionOS)
import Foundation
import MetricKit

/// Converts MetricKit hang diagnostics.
enum SentryMXHangDiagnosticProcessor: SentryMXDiagnosticProcessor {
    static let report = SentryMetricKit.DiagnosticReport.hang

    static func diagnostic(of diagnostic: MXHangDiagnostic, timestamp: Date) -> SentryMXDiagnostic {
        SentryMXDiagnostic(
            report: report,
            exceptionValue: exceptionValue(hangDuration: diagnostic.hangDuration),
            level: level(hangDuration: diagnostic.hangDuration),
            payloadTimeStampBegin: timestamp,
            diagnostic: diagnostic
        )
    }

    static func exceptionValue(hangDuration: Measurement<UnitDuration>) -> String {
        "MXHangDiagnostic hangDuration:\(SentryMXDiagnostic.measurementFormatter.string(from: hangDuration))"
    }

    static func level(hangDuration: Measurement<UnitDuration>) -> SentryLevel {
        hangDuration.converted(to: .milliseconds).value > 500 ? .error : .warning
    }
}

#if compiler(>=6.4)
@available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
extension SentryMXHangDiagnosticProcessor {
    static func diagnostic(of hang: MetricKit.HangDiagnostic, in report: MetricKit.DiagnosticReport) -> SentryMXDiagnostic {
        SentryMXDiagnostic(
            self.report,
            exceptionValue: exceptionValue(hangDuration: hang.hangDuration),
            level: level(hangDuration: hang.hangDuration),
            callStackTree: hang.callStackTree,
            in: report
        )
    }
}
#endif // compiler(>=6.4)

#endif // os(iOS) || os(macOS) || os(visionOS)
