/// Protocol for recording metrics (counters, distributions, and gauges) in Sentry.
///
/// This protocol provides a type-safe API for recording telemetry metrics that can be used
/// for monitoring application performance, tracking business metrics, and analyzing system behavior.
public protocol SentryMetricsApiProtocol {
    /// Records a count metric for the specified key.
    ///
    /// Use this to increment or set a discrete occurrence count associated with a metric key,
    /// such as the number of events, requests, or errors.
    ///
    /// - Parameters:
    ///   - key: A namespaced identifier for the metric (for example, "network.request.count").
    ///          Prefer stable, lowercase, dot-delimited names to aid aggregation and filtering.
    ///   - value: The count value to record. A non-negative integer (e.g., 1 to increment by one).
    ///            Defaults to 1.
    ///   - attributes: Optional dictionary of attributes to attach to the metric.
    ///                 Supported types: `String`, `Bool`, `Int`, `Double`, and their array variants
    ///                 (`[String]`, `[Bool]`, `[Int]`, `[Double]`). Mixed arrays and unsupported
    ///                 types are converted to strings.
    ///                 Example: `["endpoint": "api/users", "success": true, "status_code": 200]`
    func count(key: String, value: UInt, attributes: [String: SentryAttributeValue])

    /// Records a distribution metric for the specified key.
    ///
    /// Use this to track the distribution of a value over time, such as response times,
    /// request durations, or any measurable quantity where you want to analyze statistical
    /// properties (mean, median, percentiles, etc.).
    ///
    /// - Parameters:
    ///   - key: A namespaced identifier for the metric (for example, "http.request.duration").
    ///          Prefer stable, lowercase, dot-delimited names to aid aggregation and filtering.
    ///   - value: The value to record in the distribution. This can be any numeric value
    ///            representing the measurement (e.g., milliseconds for response time).
    ///   - unit: Optional unit of measurement. Use ``SentryUnit`` enum cases for type safety
    ///           (e.g., `.millisecond`, `.byte`, `.percent`), or `.generic("custom")` for custom units.
    ///   - attributes: Optional dictionary of attributes to attach to the metric.
    ///                 Supported types: `String`, `Bool`, `Int`, `Double`, and their array variants
    ///                 (`[String]`, `[Bool]`, `[Int]`, `[Double]`). Mixed arrays and unsupported
    ///                 types are converted to strings.
    ///                 Example: `["endpoint": "/api/data", "cached": false, "response_size": 1024.5]`
    func distribution(key: String, value: Double, unit: SentryUnit?, attributes: [String: SentryAttributeValue])

    /// Records a gauge metric for the specified key.
    ///
    /// Use this to track a value that can go up and down over time, such as current memory usage,
    /// queue depth, active connections, or any metric that represents a current state rather
    /// than an incrementing counter.
    ///
    /// - Parameters:
    ///   - key: A namespaced identifier for the metric (for example, "memory.usage" or "queue.depth").
    ///          Prefer stable, lowercase, dot-delimited names to aid aggregation and filtering.
    ///   - value: The current gauge value to record. This represents the state at the time of
    ///            recording (e.g., current memory in bytes, current number of items in queue).
    ///   - unit: Optional unit of measurement. Use ``SentryUnit`` enum cases for type safety
    ///           (e.g., `.millisecond`, `.byte`, `.percent`), or `.generic("custom")` for custom units.
    ///   - attributes: Optional dictionary of attributes to attach to the metric.
    ///                 Supported types: `String`, `Bool`, `Int`, `Double`, and their array variants
    ///                 (`[String]`, `[Bool]`, `[Int]`, `[Double]`). Mixed arrays and unsupported
    ///                 types are converted to strings.
    ///                 Example: `["process": "main_app", "compressed": true, "pressure_level": 2]`
    func gauge(key: String, value: Double, unit: SentryUnit?, attributes: [String: SentryAttributeValue])
}

// MARK: - Default Parameter Values
//
// Swift protocols don't support default parameter values directly. This extension provides
// convenience overloads that call through to the protocol requirements with default values.
// This pattern allows callers to omit optional parameters while keeping the protocol simple.

/// Extension providing default parameter values for metric recording methods.
public extension SentryMetricsApiProtocol {
    /// Records a count metric with default parameter values.
    ///
    /// - Parameters:
    ///   - key: A namespaced identifier for the metric
    ///   - value: The count value to record (defaults to 1)
    ///   - attributes: Optional dictionary of attributes (defaults to empty)
    func count(key: String, value: UInt = 1, attributes: [String: SentryAttributeValue] = [:]) {
        self.count(key: key, value: value, attributes: attributes)
    }

    /// Records a distribution metric with default parameter values.
    ///
    /// - Parameters:
    ///   - key: A namespaced identifier for the metric
    ///   - value: The value to record in the distribution
    ///   - unit: Optional unit of measurement (defaults to nil)
    ///   - attributes: Optional dictionary of attributes (defaults to empty)
    func distribution(key: String, value: Double, unit: SentryUnit? = nil, attributes: [String: SentryAttributeValue] = [:]) {
        self.distribution(key: key, value: value, unit: unit, attributes: attributes)
    }

    /// Records a gauge metric with default parameter values.
    ///
    /// - Parameters:
    ///   - key: A namespaced identifier for the metric
    ///   - value: The current gauge value to record
    ///   - unit: Optional unit of measurement (defaults to nil)
    ///   - attributes: Optional dictionary of attributes (defaults to empty)
    func gauge(key: String, value: Double, unit: SentryUnit? = nil, attributes: [String: SentryAttributeValue] = [:]) {
        self.gauge(key: key, value: value, unit: unit, attributes: attributes)
    }
}
