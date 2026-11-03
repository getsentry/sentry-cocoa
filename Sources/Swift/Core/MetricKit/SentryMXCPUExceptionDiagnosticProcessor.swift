#if os(iOS) || os(macOS) || os(visionOS)
import Foundation
import MetricKit

/// Converts MetricKit CPU exception diagnostics.
enum SentryMXCPUExceptionDiagnosticProcessor: SentryMXDiagnosticProcessor {
    static let report = SentryMetricKit.DiagnosticReport.cpuException

    static func diagnostic(of diagnostic: MXCPUExceptionDiagnostic, timestamp: Date) -> SentryMXDiagnostic {
        SentryMXDiagnostic(
            report: report,
            exceptionValue: exceptionValue(totalCPUTime: diagnostic.totalCPUTime, totalSampledTime: diagnostic.totalSampledTime),
            payloadTimeStampBegin: timestamp,
            diagnostic: diagnostic
        )
    }

    static func exceptionValue(totalCPUTime: Measurement<UnitDuration>, totalSampledTime: Measurement<UnitDuration>) -> String {
        let totalCPUTime = SentryMXDiagnostic.measurementFormatter.string(from: totalCPUTime)
        let totalSampledTime = SentryMXDiagnostic.measurementFormatter.string(from: totalSampledTime)
        return "MXCPUException totalCPUTime:\(totalCPUTime) totalSampledTime:\(totalSampledTime)"
    }
}

#if compiler(>=6.4)
@available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
extension SentryMXCPUExceptionDiagnosticProcessor {
    static func diagnostic(of cpuException: MetricKit.CPUExceptionDiagnostic, in report: MetricKit.DiagnosticReport) -> SentryMXDiagnostic {
        SentryMXDiagnostic(
            self.report,
            exceptionValue: exceptionValue(totalCPUTime: cpuException.totalCPUTime, totalSampledTime: cpuException.totalSampledTime),
            callStackTree: cpuException.callStackTree,
            in: report
        )
    }
}
#endif // compiler(>=6.4)

#endif // os(iOS) || os(macOS) || os(visionOS)
