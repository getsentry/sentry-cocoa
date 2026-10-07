#if canImport(MetricKit) && !os(tvOS)
// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc(SentryObjCMetricKitOptions)
public final class SentryObjCMetricKitOptions: NSObject {
    private let storage: Accessor<SentryMetricKit.Options>

    internal var wrapped: SentryMetricKit.Options {
        get { storage.value }
        set { storage.value = newValue }
    }

    internal init(parent: SentryExperimentalOptions) {
        self.storage = Accessor(root: parent, keyPath: \.metricKit)
    }

    internal init(_ wrapped: SentryMetricKit.Options) {
        self.storage = Accessor(wrapped)
    }

    @objc public override init() {
        self.storage = Accessor(SentryMetricKit.Options())
    }

    @objc public var enabledDiagnosticReports: SentryObjCMetricKitDiagnosticReport {
        get { SentryObjCMetricKitDiagnosticReportMapping.bits(for: storage.value.enabledDiagnosticReports) }
        set { storage.value.enabledDiagnosticReports = SentryObjCMetricKitDiagnosticReportMapping.reports(for: newValue) }
    }
}

// swiftlint:enable missing_docs
#endif // canImport(MetricKit) && !os(tvOS)
