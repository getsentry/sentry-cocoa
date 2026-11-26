// MetricManager only exists in the SDKs of Xcode 27 and later, and only reports memory exceptions
// on iOS.
#if os(iOS) && !targetEnvironment(macCatalyst) && compiler(>=6.4)
import Foundation
import MetricKit

/// Converts MetricKit memory exception diagnostics, which only `MetricManager` reports.
@available(iOS 27.0, *)
enum SentryMXMemoryExceptionDiagnosticProcessor {
    static let report = SentryMetricKit.DiagnosticReport.memoryException

    static func diagnostic(of memoryException: MetricKit.MemoryExceptionDiagnostic, in report: MetricKit.DiagnosticReport) -> SentryMXDiagnostic {
        SentryMXDiagnostic(
            self.report,
            exceptionValue: "The app or extension exceeded its memory limit",
            callStackTree: memoryException.callStackTree,
            in: report
        )
    }
}

#endif // os(iOS) && !targetEnvironment(macCatalyst) && compiler(>=6.4)
