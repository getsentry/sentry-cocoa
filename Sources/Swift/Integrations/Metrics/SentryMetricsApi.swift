@_implementationOnly import _SentryPrivate
import Foundation

public class SentryMetricsApi {
    /// Records a count metric for the specified key.
    ///
    /// Use this to increment or set a discrete occurrence count associated with a metric key,
    /// such as the number of events, requests, or errors.
    ///
    /// - Parameters:
    ///   - key: A namespaced identifier for the metric (for example, "network.request.count").
    ///          Prefer stable, lowercase, dot-delimited names to aid aggregation and filtering.
    ///   - value: The count value to record. Typically a non-negative integer (e.g., 1 to increment by one).
    ///            Values less than zero may be ignored or clamped by the metrics backend.
    ///   - unit: Optional unit of measurement (e.g., "request", "error")
    ///   - attributes: Optional dictionary of attributes to attach to the metric.
    ///                 Values can be String, Bool, Int, Double, Float, or SentryAttribute.
    ///                 Example: `["endpoint": "api/users", "success": true, "status_code": 200]`
    public func count(key: String, value: Int, unit: String? = nil, attributes: [String: SentryAttributable] = [:]) {
        recordMetric(name: key, value: .integer(Int64(value)), type: .counter, unit: unit, attributes: attributes)
    }

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
    ///   - unit: Optional unit of measurement (e.g., "millisecond", "byte")
    ///   - attributes: Optional dictionary of attributes to attach to the metric.
    ///                 Values can be String, Bool, Int, Double, Float, or SentryAttribute.
    ///                 Example: `["endpoint": "/api/data", "cached": false, "response_size": 1024.5]`
    public func distribution(key: String, value: Double, unit: String? = nil, attributes: [String: SentryAttributable] = [:]) {
        recordMetric(name: key, value: .double(value), type: .distribution, unit: unit, attributes: attributes)
    }

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
    ///   - unit: Optional unit of measurement (e.g., "byte", "connection")
    ///   - attributes: Optional dictionary of attributes to attach to the metric.
    ///                 Values can be String, Bool, Int, Double, Float, or SentryAttribute.
    ///                 Example: `["process": "main_app", "compressed": true, "pressure_level": 2]`
    public func gauge(key: String, value: Double, unit: String? = nil, attributes: [String: SentryAttributable] = [:]) {
        recordMetric(name: key, value: .double(value), type: .gauge, unit: unit, attributes: attributes)
    }

    // MARK: - Private

    private func recordMetric(
        name: String,
        value: SentryMetricValue,
        type: SentryMetricType,
        unit: String?,
        attributes: [String: SentryAttributable]
    ) {
        guard SentrySDKInternal.isEnabled else {
            return
        }
        let hub = SentrySDKInternal.currentHub()
        guard let options = hub.getClient()?.getOptions() as? Options, options.enableMetrics else {
            return
        }
        guard let integration = hub.getInstalledIntegration(SentryMetricsIntegration<SentryDependencyContainer>.self) as? SentryMetricsIntegration<SentryDependencyContainer> else {
            return
        }

        let metric = SentryMetric(
            timestamp: Date(),
            traceId: SentryId.empty, // Will be set by batcher from scope
            name: name,
            value: value,
            type: type,
            unit: unit,
            attributes: attributes.mapValues { attributable in
                attributable.asAttribute
            }
        )
        integration.addMetric(metric, scope: hub.scope)
    }
}
