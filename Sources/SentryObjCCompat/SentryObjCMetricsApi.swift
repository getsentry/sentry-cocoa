// swiftlint:disable missing_docs
internal import Sentry
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
