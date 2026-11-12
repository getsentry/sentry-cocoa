/// Protocol for recording metrics (counters, distributions, and gauges) in Sentry.
///
/// This protocol provides a type-safe API for recording telemetry metrics that can be used
/// for monitoring application performance, tracking business metrics, and analyzing system behavior.
///
/// Every method takes the metric name, the value and optional ``SentryMetricOptions``, matching
/// `Sentry.metrics.count(name, value, options)` and its gauge and distribution counterparts in the
/// other Sentry SDKs.
public protocol SentryMetricsApiProtocol {
    /// Records a count metric with the specified name.
    ///
    /// Use this to increment or set a discrete occurrence count associated with a metric name,
    /// such as the number of events, requests, or errors.
    ///
    /// - Parameters:
    ///   - name: A namespaced identifier for the metric (for example, "network.request.count").
    ///           Prefer stable, lowercase, dot-delimited names to aid aggregation and filtering.
    ///   - value: The count value to record. A non-negative integer (e.g., 1 to increment by one).
    ///   - options: Optional attributes, scope and timestamp of the metric. Count metrics ignore
    ///              ``SentryMetricOptions/unit``.
    ///              Example: `SentryMetricOptions(attributes: ["endpoint": "api/users", "status_code": 200])`
    func count(_ name: String, value: UInt, options: SentryMetricOptions)

    /// Records a distribution metric with the specified name.
    ///
    /// Use this to track the distribution of a value over time, such as response times,
    /// request durations, or any measurable quantity where you want to analyze statistical
    /// properties (mean, median, percentiles, etc.).
    ///
    /// - Parameters:
    ///   - name: A namespaced identifier for the metric (for example, "http.request.duration").
    ///           Prefer stable, lowercase, dot-delimited names to aid aggregation and filtering.
    ///   - value: The value to record in the distribution. This can be any numeric value
    ///            representing the measurement (e.g., milliseconds for response time).
    ///   - options: Optional unit, attributes, scope and timestamp of the metric.
    ///              Example: `SentryMetricOptions(unit: .millisecond, attributes: ["cached": false])`
    func distribution(_ name: String, value: Double, options: SentryMetricOptions)

    /// Records a gauge metric with the specified name.
    ///
    /// Use this to track a value that can go up and down over time, such as current memory usage,
    /// queue depth, active connections, or any metric that represents a current state rather
    /// than an incrementing counter.
    ///
    /// - Parameters:
    ///   - name: A namespaced identifier for the metric (for example, "memory.usage" or "queue.depth").
    ///           Prefer stable, lowercase, dot-delimited names to aid aggregation and filtering.
    ///   - value: The current gauge value to record. This represents the state at the time of
    ///            recording (e.g., current memory in bytes, current number of items in queue).
    ///   - options: Optional unit, attributes, scope and timestamp of the metric.
    ///              Example: `SentryMetricOptions(unit: .byte, attributes: ["process": "main_app"])`
    func gauge(_ name: String, value: Double, options: SentryMetricOptions)

    #if !SDK_V10
    /// Records a count metric for the specified key.
    ///
    /// - Parameters:
    ///   - key: A namespaced identifier for the metric (for example, "network.request.count").
    ///   - value: The count value to record.
    ///   - attributes: Dictionary of attributes to attach to the metric.
    @available(*, deprecated, message: "Use count(_:value:options:) instead, passing attributes through SentryMetricOptions. This method will be removed in v10.")
    func count(key: String, value: UInt, attributes: [String: SentryAttributeValue])

    /// Records a distribution metric for the specified key.
    ///
    /// - Parameters:
    ///   - key: A namespaced identifier for the metric (for example, "http.request.duration").
    ///   - value: The value to record in the distribution.
    ///   - unit: Optional unit of measurement.
    ///   - attributes: Dictionary of attributes to attach to the metric.
    @available(*, deprecated, message: "Use distribution(_:value:options:) instead, passing unit and attributes through SentryMetricOptions. This method will be removed in v10.")
    func distribution(key: String, value: Double, unit: SentryUnit?, attributes: [String: SentryAttributeValue])

    /// Records a gauge metric for the specified key.
    ///
    /// - Parameters:
    ///   - key: A namespaced identifier for the metric (for example, "memory.usage" or "queue.depth").
    ///   - value: The current gauge value to record.
    ///   - unit: Optional unit of measurement.
    ///   - attributes: Dictionary of attributes to attach to the metric.
    @available(*, deprecated, message: "Use gauge(_:value:options:) instead, passing unit and attributes through SentryMetricOptions. This method will be removed in v10.")
    func gauge(key: String, value: Double, unit: SentryUnit?, attributes: [String: SentryAttributeValue])
    #endif // !SDK_V10
}

// MARK: - Default Parameter Values
//
// Swift protocols don't support default parameter values directly. This extension provides
// convenience overloads that call through to the protocol requirements with default values.
// This pattern allows callers to omit optional parameters while keeping the protocol simple.

/// Extension providing default parameter values for metric recording methods.
public extension SentryMetricsApiProtocol {
    /// Records a count metric without options.
    ///
    /// - Parameters:
    ///   - name: A namespaced identifier for the metric
    ///   - value: The count value to record (defaults to 1)
    func count(_ name: String, value: UInt = 1) {
        self.count(name, value: value, options: SentryMetricOptions())
    }

    /// Records a distribution metric without options.
    ///
    /// - Parameters:
    ///   - name: A namespaced identifier for the metric
    ///   - value: The value to record in the distribution
    func distribution(_ name: String, value: Double) {
        self.distribution(name, value: value, options: SentryMetricOptions())
    }

    /// Records a gauge metric without options.
    ///
    /// - Parameters:
    ///   - name: A namespaced identifier for the metric
    ///   - value: The current gauge value to record
    func gauge(_ name: String, value: Double) {
        self.gauge(name, value: value, options: SentryMetricOptions())
    }
}

#if !SDK_V10
// MARK: - Deprecated API
//
// Types conforming to SentryMetricsApiProtocol before the options API existed only implement the
// key-based requirements. The default implementations below keep them compiling: the options-based
// requirements fall back to the key-based ones, and the key-based ones forward to the options-based
// ones for conformers that only implement the new requirements.

/// Extension bridging the deprecated key-based API and the options-based API.
public extension SentryMetricsApiProtocol {
    /// Default implementation for conformers that only implement ``count(key:value:attributes:)``.
    ///
    /// Drops ``SentryMetricOptions/scope`` and ``SentryMetricOptions/timestamp``.
    @available(*, deprecated, message: "Implement count(_:value:options:). This default implementation drops the scope and timestamp options and will be removed in v10.")
    func count(_ name: String, value: UInt, options: SentryMetricOptions) {
        self.count(key: name, value: value, attributes: options.attributes)
    }

    /// Default implementation for conformers that only implement ``distribution(key:value:unit:attributes:)``.
    ///
    /// Drops ``SentryMetricOptions/scope`` and ``SentryMetricOptions/timestamp``.
    @available(*, deprecated, message: "Implement distribution(_:value:options:). This default implementation drops the scope and timestamp options and will be removed in v10.")
    func distribution(_ name: String, value: Double, options: SentryMetricOptions) {
        self.distribution(key: name, value: value, unit: options.unit, attributes: options.attributes)
    }

    /// Default implementation for conformers that only implement ``gauge(key:value:unit:attributes:)``.
    ///
    /// Drops ``SentryMetricOptions/scope`` and ``SentryMetricOptions/timestamp``.
    @available(*, deprecated, message: "Implement gauge(_:value:options:). This default implementation drops the scope and timestamp options and will be removed in v10.")
    func gauge(_ name: String, value: Double, options: SentryMetricOptions) {
        self.gauge(key: name, value: value, unit: options.unit, attributes: options.attributes)
    }

    /// Records a count metric for the specified key.
    ///
    /// - Parameters:
    ///   - key: A namespaced identifier for the metric
    ///   - value: The count value to record (defaults to 1)
    ///   - attributes: Optional dictionary of attributes (defaults to empty)
    @available(*, deprecated, message: "Use count(_:value:options:) instead, passing attributes through SentryMetricOptions. This method will be removed in v10.")
    func count(key: String, value: UInt = 1, attributes: [String: SentryAttributeValue] = [:]) {
        self.count(key, value: value, options: SentryMetricOptions(attributes: attributes))
    }

    /// Records a distribution metric for the specified key.
    ///
    /// - Parameters:
    ///   - key: A namespaced identifier for the metric
    ///   - value: The value to record in the distribution
    ///   - unit: Optional unit of measurement (defaults to nil)
    ///   - attributes: Optional dictionary of attributes (defaults to empty)
    @available(*, deprecated, message: "Use distribution(_:value:options:) instead, passing unit and attributes through SentryMetricOptions. This method will be removed in v10.")
    func distribution(key: String, value: Double, unit: SentryUnit? = nil, attributes: [String: SentryAttributeValue] = [:]) {
        self.distribution(key, value: value, options: SentryMetricOptions(unit: unit, attributes: attributes))
    }

    /// Records a gauge metric for the specified key.
    ///
    /// - Parameters:
    ///   - key: A namespaced identifier for the metric
    ///   - value: The current gauge value to record
    ///   - unit: Optional unit of measurement (defaults to nil)
    ///   - attributes: Optional dictionary of attributes (defaults to empty)
    @available(*, deprecated, message: "Use gauge(_:value:options:) instead, passing unit and attributes through SentryMetricOptions. This method will be removed in v10.")
    func gauge(key: String, value: Double, unit: SentryUnit? = nil, attributes: [String: SentryAttributeValue] = [:]) {
        self.gauge(key, value: value, options: SentryMetricOptions(unit: unit, attributes: attributes))
    }
}
#endif // !SDK_V10
