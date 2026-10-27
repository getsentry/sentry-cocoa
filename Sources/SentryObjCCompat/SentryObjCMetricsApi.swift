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

    @objc(count:value:options:) public func count(_ name: String, value: UInt, options: SentryObjCMetricOptions) {
        api.count(name, value: value, options: options.toSentryMetricOptions())
    }

    @objc(count:value:) public func count(_ name: String, value: UInt) {
        api.count(name, value: value, options: SentryMetricOptions())
    }

    @objc(count:) public func count(_ name: String) {
        api.count(name, value: 1, options: SentryMetricOptions())
    }

    @objc(distribution:value:options:) public func distribution(_ name: String, value: Double, options: SentryObjCMetricOptions) {
        api.distribution(name, value: value, options: options.toSentryMetricOptions())
    }

    @objc(distribution:value:) public func distribution(_ name: String, value: Double) {
        api.distribution(name, value: value, options: SentryMetricOptions())
    }

    @objc(gauge:value:options:) public func gauge(_ name: String, value: Double, options: SentryObjCMetricOptions) {
        api.gauge(name, value: value, options: options.toSentryMetricOptions())
    }

    @objc(gauge:value:) public func gauge(_ name: String, value: Double) {
        api.gauge(name, value: value, options: SentryMetricOptions())
    }

    #if !SDK_V10
    // Deprecated in SentryObjCMetricsApi.h. They forward to the options-based Swift API so the
    // wrapper doesn't call the deprecated Swift methods.

    @objc public func count(key: String, value: UInt, attributes: [String: SentryObjCAttributeContent]) {
        api.count(key, value: value, options: SentryMetricOptions(attributes: mapAttributes(attributes)))
    }

    @objc public func count(key: String, value: UInt) {
        api.count(key, value: value, options: SentryMetricOptions())
    }

    @objc public func count(key: String) {
        api.count(key, value: 1, options: SentryMetricOptions())
    }

    @objc public func distribution(key: String, value: Double, unit: SentryObjCUnit?, attributes: [String: SentryObjCAttributeContent]) {
        api.distribution(key, value: value, options: SentryMetricOptions(unit: unit?.toSentryUnit(), attributes: mapAttributes(attributes)))
    }

    @objc public func distribution(key: String, value: Double, unit: SentryObjCUnit?) {
        api.distribution(key, value: value, options: SentryMetricOptions(unit: unit?.toSentryUnit()))
    }

    @objc public func distribution(key: String, value: Double) {
        api.distribution(key, value: value, options: SentryMetricOptions())
    }

    @objc public func gauge(key: String, value: Double, unit: SentryObjCUnit?, attributes: [String: SentryObjCAttributeContent]) {
        api.gauge(key, value: value, options: SentryMetricOptions(unit: unit?.toSentryUnit(), attributes: mapAttributes(attributes)))
    }

    @objc public func gauge(key: String, value: Double, unit: SentryObjCUnit?) {
        api.gauge(key, value: value, options: SentryMetricOptions(unit: unit?.toSentryUnit()))
    }

    @objc public func gauge(key: String, value: Double) {
        api.gauge(key, value: value, options: SentryMetricOptions())
    }

    #endif // !SDK_V10

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

extension SentryAttributeContent {
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
