// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc public enum SentryObjCMetricKitHangReportingMode: Int {
    case legacy = 0
    case flamegraphAttachment = 1
}

@objc(SentryObjCMetricKitOptions) public final class SentryObjCMetricKitOptions: NSObject {
    internal let wrapped: SentryMetricKitOptions

    internal init(_ wrapped: SentryMetricKitOptions) {
        self.wrapped = wrapped
    }

    #if canImport(MetricKit) && !os(tvOS)
    @objc public var enabledDiagnosticReports: SentryObjCMetricKitDiagnosticReport {
        get { SentryObjCMetricKitDiagnosticReportMapping.bits(for: wrapped.enabledDiagnosticReports) }
        set { wrapped.enabledDiagnosticReports = SentryObjCMetricKitDiagnosticReportMapping.reports(for: newValue) }
    }

    @objc public var enabledMetricReports: SentryObjCMetricKitMetricReport {
        get { SentryObjCMetricKitMetricReportMapping.bits(for: wrapped.enabledMetricReports) }
        set { wrapped.enabledMetricReports = SentryObjCMetricKitMetricReportMapping.reports(for: newValue) }
    }
    #endif // canImport(MetricKit) && !os(tvOS)

    @objc public var hangReportingMode: SentryObjCMetricKitHangReportingMode {
        get {
            switch wrapped.hangReportingMode {
            case .legacy: return .legacy
            case .flamegraphAttachment: return .flamegraphAttachment
            @unknown default: return .legacy
            }
        }
        set {
            switch newValue {
            case .legacy: wrapped.hangReportingMode = .legacy
            case .flamegraphAttachment: wrapped.hangReportingMode = .flamegraphAttachment
            }
        }
    }
}
// swiftlint:enable missing_docs
