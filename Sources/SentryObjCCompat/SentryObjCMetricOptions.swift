// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc(SentryObjCMetricOptions) public final class SentryObjCMetricOptions: NSObject {
    @objc public var unit: SentryObjCUnit?
    @objc public var attributes: [String: SentryObjCAttributeContent] = [:]
    @objc public var scope: SentryObjCScope?
    @objc public var timestamp: Date?

    @objc public override init() {
        super.init()
    }

    internal func toSentryMetricOptions() -> SentryMetricOptions {
        SentryMetricOptions(
            unit: unit?.toSentryUnit(),
            attributes: attributes.mapValues { $0.toAttributeContent().asAttributeValue },
            scope: scope?.wrapped,
            timestamp: timestamp
        )
    }
}

// swiftlint:enable missing_docs
