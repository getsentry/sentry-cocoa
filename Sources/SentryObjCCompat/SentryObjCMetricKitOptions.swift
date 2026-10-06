// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc public enum SentryObjCMetricKitHangReportingMode: Int {
    case legacy = 0
    case culprit = 1
}

@objc(SentryObjCMetricKitOptions) public final class SentryObjCMetricKitOptions: NSObject {
    internal let wrapped: SentryMetricKitOptions

    internal init(_ wrapped: SentryMetricKitOptions) {
        self.wrapped = wrapped
    }

    @objc public var hangReportingMode: SentryObjCMetricKitHangReportingMode {
        get {
            switch wrapped.hangReportingMode {
            case .legacy: return .legacy
            case .culprit: return .culprit
            @unknown default: return .legacy
            }
        }
        set {
            switch newValue {
            case .legacy: wrapped.hangReportingMode = .legacy
            case .culprit: wrapped.hangReportingMode = .culprit
            }
        }
    }
}
// swiftlint:enable missing_docs
