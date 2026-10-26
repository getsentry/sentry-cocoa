import Foundation

/// Optional values for recording a metric with ``SentryMetricsApiProtocol``.
///
/// Mirrors the `options` parameter of `Sentry.metrics.count(name, value, options)`,
/// `Sentry.metrics.gauge(name, value, options)` and
/// `Sentry.metrics.distribution(name, value, options)` in the other Sentry SDKs.
///
/// ```swift
/// SentrySDK.metrics.distribution(
///     "http.request.duration",
///     value: 187.5,
///     options: SentryMetricOptions(unit: .millisecond, attributes: ["endpoint": "/api/data"])
/// )
/// ```
public struct SentryMetricOptions {
    /// The unit of measurement of the metric value.
    ///
    /// Only used by gauge and distribution metrics. Count metrics ignore it.
    /// Use ``SentryUnit`` enum cases (e.g., `.millisecond`, `.byte`, `.percent`), or
    /// `.generic("custom")` for custom units.
    public var unit: SentryUnit?

    /// Attributes to attach to the metric.
    ///
    /// Supported types: `String`, `Bool`, `Int`, `Double`, and their array variants
    /// (`[String]`, `[Bool]`, `[Int]`, `[Double]`). Mixed arrays and unsupported
    /// types are converted to strings.
    /// Attributes passed here take precedence over scope attributes with the same key.
    public var attributes: [String: SentryAttributeValue]

    /// The scope to capture the metric with.
    ///
    /// The scope is applied on top of the global scope, in the same way as a current scope set
    /// by hybrid SDKs. When `nil`, the metric uses the current scope of the calling thread, if any.
    public var scope: Scope?

    /// The time the metric was recorded.
    ///
    /// When `nil`, the SDK uses the time the metric is captured.
    public var timestamp: Date?

    /// Creates options for recording a metric.
    ///
    /// - Parameters:
    ///   - unit: The unit of measurement. Only used by gauge and distribution metrics.
    ///   - attributes: Attributes to attach to the metric.
    ///   - scope: The scope to capture the metric with.
    ///   - timestamp: The time the metric was recorded. Defaults to the capture time.
    public init(
        unit: SentryUnit? = nil,
        attributes: [String: SentryAttributeValue] = [:],
        scope: Scope? = nil,
        timestamp: Date? = nil
    ) {
        self.unit = unit
        self.attributes = attributes
        self.scope = scope
        self.timestamp = timestamp
    }
}
