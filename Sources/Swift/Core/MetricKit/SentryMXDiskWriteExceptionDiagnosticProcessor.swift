#if os(iOS) || os(macOS) || os(visionOS)
import Foundation
import MetricKit

/// Converts MetricKit disk write exception diagnostics.
enum SentryMXDiskWriteExceptionDiagnosticProcessor: SentryMXDiagnosticProcessor {
    static let report = SentryMetricKit.DiagnosticReport.diskWriteException

    static func diagnostic(of diagnostic: MXDiskWriteExceptionDiagnostic, timestamp: Date) -> SentryMXDiagnostic {
        SentryMXDiagnostic(
            report: report,
            exceptionValue: exceptionValue(totalWritesCaused: diagnostic.totalWritesCaused),
            payloadTimeStampBegin: timestamp,
            diagnostic: diagnostic
        )
    }

    static func exceptionValue(totalWritesCaused: Measurement<UnitInformationStorage>) -> String {
        "MXDiskWriteException totalWritesCaused:\(SentryMXDiagnostic.measurementFormatter.string(from: totalWritesCaused))"
    }
}

#if compiler(>=6.4)
@available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
extension SentryMXDiskWriteExceptionDiagnosticProcessor {
    static func diagnostic(of diskWriteException: MetricKit.DiskWriteExceptionDiagnostic, in report: MetricKit.DiagnosticReport) -> SentryMXDiagnostic {
        SentryMXDiagnostic(
            self.report,
            exceptionValue: exceptionValue(totalWritesCaused: diskWriteException.totalBytesWritten),
            callStackTree: diskWriteException.callStackTree,
            in: report
        )
    }
}
#endif // compiler(>=6.4)

#endif // os(iOS) || os(macOS) || os(visionOS)
