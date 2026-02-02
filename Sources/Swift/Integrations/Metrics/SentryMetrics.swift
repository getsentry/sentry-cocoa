import Foundation

/// Objective-C compatible wrapper for the Sentry Metrics API.
///
/// This class provides an Objective-C accessible interface to the underlying Swift metrics API.
/// It accepts `String` for units (matching the raw value of ``SentryUnit``) and `[String: Any]`
/// for attributes, converting them to the Swift-native types internally.
///
/// Swift callers can use the type-safe ``SentryUnit`` and ``SentryAttributeValue`` parameters
/// directly through the ``SentryMetricsApiProtocol`` conformance on this class.
///
/// - Important: From Objective-C, pass unit names as plain strings (e.g., `@"millisecond"`,
///   `@"byte"`) and attributes as `NSDictionary<NSString *, id>`. The wrapper converts these
///   to the Swift-native types internally.
@objc
public final class SentryMetrics: NSObject {
    private let api: SentryMetricsApiProtocol

    init(api: SentryMetricsApiProtocol) {
        self.api = api
        super.init()
    }

    // MARK: - Count

    /// Records a count metric, incrementing the specified key by 1.
    @objc(countWithKey:)
    public func count(key: String) {
        api.count(key: key, value: 1)
    }

    /// Records a count metric with the specified key and value.
    @objc(countWithKey:value:)
    public func count(key: String, value: UInt) {
        api.count(key: key, value: value)
    }

    /// Records a count metric with the specified key, value, and unit.
    @objc(countWithKey:value:unit:)
    public func count(key: String, value: UInt, unit: String?) {
        api.count(key: key, value: value, unit: sentryUnit(from: unit))
    }

    /// Records a count metric with the specified key, value, unit, and attributes.
    @objc(countWithKey:value:unit:attributes:)
    public func count(key: String, value: UInt, unit: String?, attributes: [String: Any]) {
        api.count(key: key, value: value, unit: sentryUnit(from: unit), attributes: convertAttributes(attributes))
    }

    // MARK: - Distribution

    /// Records a distribution metric with the specified key and value.
    @objc(distributionWithKey:value:)
    public func distribution(key: String, value: Double) {
        api.distribution(key: key, value: value)
    }

    /// Records a distribution metric with the specified key, value, and unit.
    @objc(distributionWithKey:value:unit:)
    public func distribution(key: String, value: Double, unit: String?) {
        api.distribution(key: key, value: value, unit: sentryUnit(from: unit))
    }

    /// Records a distribution metric with the specified key, value, unit, and attributes.
    @objc(distributionWithKey:value:unit:attributes:)
    public func distribution(key: String, value: Double, unit: String?, attributes: [String: Any]) {
        api.distribution(key: key, value: value, unit: sentryUnit(from: unit), attributes: convertAttributes(attributes))
    }

    // MARK: - Gauge

    /// Records a gauge metric with the specified key and value.
    @objc(gaugeWithKey:value:)
    public func gauge(key: String, value: Double) {
        api.gauge(key: key, value: value)
    }

    /// Records a gauge metric with the specified key, value, and unit.
    @objc(gaugeWithKey:value:unit:)
    public func gauge(key: String, value: Double, unit: String?) {
        api.gauge(key: key, value: value, unit: sentryUnit(from: unit))
    }

    /// Records a gauge metric with the specified key, value, unit, and attributes.
    @objc(gaugeWithKey:value:unit:attributes:)
    public func gauge(key: String, value: Double, unit: String?, attributes: [String: Any]) {
        api.gauge(key: key, value: value, unit: sentryUnit(from: unit), attributes: convertAttributes(attributes))
    }

    // MARK: - Private

    private func sentryUnit(from string: String?) -> SentryUnit? {
        guard let string, !string.isEmpty else { return nil }
        return SentryUnit(rawValue: string)
    }

    private func convertAttributes(_ attrs: [String: Any]) -> [String: SentryAttributeValue] {
        attrs.mapValues { SentryAttribute(value: $0) }
    }
}

// Conformance needed so SentryMetrics can also be used through the protocol-based Swift API.
extension SentryMetrics: SentryMetricsApiProtocol {
    public func count(key: String, value: UInt, unit: SentryUnit?, attributes: [String: SentryAttributeValue]) {
        api.count(key: key, value: value, unit: unit, attributes: attributes)
    }

    public func distribution(key: String, value: Double, unit: SentryUnit?, attributes: [String: SentryAttributeValue]) {
        api.distribution(key: key, value: value, unit: unit, attributes: attributes)
    }

    public func gauge(key: String, value: Double, unit: SentryUnit?, attributes: [String: SentryAttributeValue]) {
        api.gauge(key: key, value: value, unit: unit, attributes: attributes)
    }
}
