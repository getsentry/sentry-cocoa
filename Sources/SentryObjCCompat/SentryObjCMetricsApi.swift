// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc(SentryObjCMetricsApi) public final class SentryObjCMetricsApi: NSObject {
    private let api: SentryMetricsApiProtocol

    internal init(_ api: SentryMetricsApiProtocol) {
        self.api = api
    }

    @objc public func count(key: String, value: UInt, attributes: [String: SentryObjCAttributeContent]) {
        api.count(key: key, value: value, attributes: mapAttributes(attributes))
    }

    @objc public func count(key: String, value: UInt) {
        api.count(key: key, value: value, attributes: [:])
    }

    @objc public func count(key: String) {
        api.count(key: key, value: 1, attributes: [:])
    }

    @objc public func distribution(key: String, value: Double, unit: SentryObjCUnit?, attributes: [String: SentryObjCAttributeContent]) {
        api.distribution(key: key, value: value, unit: unit?.toSentryUnit(), attributes: mapAttributes(attributes))
    }

    @objc public func distribution(key: String, value: Double, unit: SentryObjCUnit?) {
        api.distribution(key: key, value: value, unit: unit?.toSentryUnit(), attributes: [:])
    }

    @objc public func distribution(key: String, value: Double) {
        api.distribution(key: key, value: value, unit: nil, attributes: [:])
    }

    @objc public func gauge(key: String, value: Double, unit: SentryObjCUnit?, attributes: [String: SentryObjCAttributeContent]) {
        api.gauge(key: key, value: value, unit: unit?.toSentryUnit(), attributes: mapAttributes(attributes))
    }

    @objc public func gauge(key: String, value: Double, unit: SentryObjCUnit?) {
        api.gauge(key: key, value: value, unit: unit?.toSentryUnit(), attributes: [:])
    }

    @objc public func gauge(key: String, value: Double) {
        api.gauge(key: key, value: value, unit: nil, attributes: [:])
    }

    private func mapAttributes(_ attributes: [String: SentryObjCAttributeContent]) -> [String: any SentryAttributeValue] {
        attributes.mapValues { $0.toAttributeContent().asAttributeValue }
    }

    // MARK: - Testing

    /// Test-only initializer. Do not use in production code.
    @objc public convenience init(testApi: NSObject) {
        guard let api = testApi as? SentryMetricsApiProtocol else {
            preconditionFailure("testApi must conform to SentryMetricsApiProtocol")
        }
        self.init(api)
    }
}

private extension SentryAttributeContent {
    var asAttributeValue: any SentryAttributeValue {
        switch self {
        case .string(let v): return v
        case .boolean(let v): return v
        case .integer(let v): return v
        case .double(let v): return v
        case .stringArray(let v): return v
        case .booleanArray(let v): return v
        case .integerArray(let v): return v
        case .doubleArray(let v): return v
        @unknown default: return String(describing: self)
        }
    }
}

// swiftlint:enable missing_docs
