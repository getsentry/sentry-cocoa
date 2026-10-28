#if os(iOS) || os(macOS) || os(visionOS)
import Foundation
import MetricKit

/// Converts MetricKit app launch diagnostics.
///
/// The legacy API reports app launches on iOS 16 and later and on visionOS, and `MetricManager`
/// on iOS and macOS 27 and later.
enum SentryMXAppLaunchDiagnosticProcessor {
    static let report = SentryMetricKit.DiagnosticReport.appLaunch

    static func exceptionValue(launchDuration: Measurement<UnitDuration>) -> String {
        "MXAppLaunchDiagnostic launchDuration:\(SentryMXDiagnostic.measurementFormatter.string(from: launchDuration))"
    }
}

#if os(iOS) || os(visionOS)
@available(iOS 16.0, *)
extension SentryMXAppLaunchDiagnosticProcessor: SentryMXDiagnosticProcessor {
    static func diagnostic(of diagnostic: MXAppLaunchDiagnostic, timestamp: Date) -> SentryMXDiagnostic {
        SentryMXDiagnostic(
            report: report,
            exceptionValue: exceptionValue(launchDuration: diagnostic.launchDuration),
            payloadTimeStampBegin: timestamp,
            diagnostic: diagnostic
        )
    }
}
#endif // os(iOS) || os(visionOS)

#if !os(visionOS) && compiler(>=6.4)
@available(iOS 27.0, macOS 27.0, *)
extension SentryMXAppLaunchDiagnosticProcessor {
    static func diagnostic(of appLaunch: MetricKit.AppLaunchDiagnostic, in report: MetricKit.DiagnosticReport) -> SentryMXDiagnostic {
        SentryMXDiagnostic(
            self.report,
            exceptionValue: exceptionValue(launchDuration: appLaunch.launchDuration),
            callStackTree: appLaunch.callStackTree,
            in: report
        )
    }
}
#endif // !os(visionOS) && compiler(>=6.4)

#endif // os(iOS) || os(macOS) || os(visionOS)
