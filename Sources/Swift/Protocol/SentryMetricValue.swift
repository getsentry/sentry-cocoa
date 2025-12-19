/// Represents the numeric value of a metric with type-safe distinction between integers and doubles.
///
/// This enum provides type safety to prevent accidentally mixing integer and floating-point values,
/// especially useful in `beforeSendMetric` callbacks where you need to ensure counters remain integers
/// and distributions remain doubles.
///
/// Example usage in `beforeSendMetric`:
/// ```swift
/// options.beforeSendMetric = { metric in
///     var modified = metric
///     switch modified.value {
///     case .counter(let intValue):
///         // Can safely modify as integer - e.g., for counters
///         modified.value = .counter(intValue + 1)
///     case .gauge(let doubleValue):
///         // Can safely modify as double - e.g., for gauges
///         modified.value = .gauge(doubleValue * 1.5)
///     case .distribution(let doubleValue):
///         // Can safely modify as double - e.g., for distributions
///         modified.value = .distribution(doubleValue * 1.5)
///     }
///     return modified
/// }
/// ```
public enum SentryMetricValue: Equatable, Hashable {
    /// Incrementing integer values that only increase (e.g., request counts)
    case counter(_ value: UInt)

    /// Current value at a point in time that can fluctuate (e.g., active connections)
    case gauge(_ value: Double)

    /// Statistical distribution of values for aggregation (e.g., response times)
    case distribution(_ value: Double)
}

extension SentryMetricValue: Encodable {
    private enum CodingKeys: String, CodingKey {
        case metricType = "type"
        case value
    }

    /// Encodes the value according to the metrics specification.
    ///
    /// Integer values are encoded as `Int64` and double values as `Double` to ensure
    /// accurate representation in the metric payload.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .counter(let value):
            try container.encode("counter", forKey: .metricType)
            try container.encode(Int64(truncatingIfNeeded: value), forKey: .value)
        case .gauge(let value):
            try container.encode("gauge", forKey: .metricType)
            try container.encode(value, forKey: .value)
        case .distribution(let value):
            try container.encode("distribution", forKey: .metricType)
            try container.encode(value, forKey: .value)
        }
    }
}
