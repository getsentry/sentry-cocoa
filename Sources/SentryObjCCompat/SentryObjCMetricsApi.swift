// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif

public final class SentryObjCMetricsApi: NSObject {
    private let api: SentryMetricsApiProtocol

    internal init(_ api: SentryMetricsApiProtocol) {
        self.api = api
    }

    @objc public func count(key: String, value: UInt, attributes: [String: SentryObjCAttributeContent]) {
        api.count(key: key, value: value, attributes: attributes.mapValues { $0.toAttributeContent() })
    }

    @objc public func count(key: String, value: UInt) {
        api.count(key: key, value: value, attributes: [:])
    }

    @objc public func count(key: String) {
        api.count(key: key, value: 1, attributes: [:])
    }

    @objc public func distribution(key: String, value: Double, unit: SentryObjCUnit?, attributes: [String: SentryObjCAttributeContent]) {
        api.distribution(key: key, value: value, unit: unit?.toSentryUnit(), attributes: attributes.mapValues { $0.toAttributeContent() })
    }

    @objc public func distribution(key: String, value: Double, unit: SentryObjCUnit?) {
        api.distribution(key: key, value: value, unit: unit?.toSentryUnit(), attributes: [:])
    }

    @objc public func distribution(key: String, value: Double) {
        api.distribution(key: key, value: value, unit: nil, attributes: [:])
    }

    @objc public func gauge(key: String, value: Double, unit: SentryObjCUnit?, attributes: [String: SentryObjCAttributeContent]) {
        api.gauge(key: key, value: value, unit: unit?.toSentryUnit(), attributes: attributes.mapValues { $0.toAttributeContent() })
    }

    @objc public func gauge(key: String, value: Double, unit: SentryObjCUnit?) {
        api.gauge(key: key, value: value, unit: unit?.toSentryUnit(), attributes: [:])
    }

    @objc public func gauge(key: String, value: Double) {
        api.gauge(key: key, value: value, unit: nil, attributes: [:])
    }
}

// swiftlint:enable missing_docs
