/// A metric entry that captures metric data with associated attribute metadata.
///
/// Use the `options.beforeSendMetric` callback to modify or filter metric data.
public struct SentryMetric {
    /// A typed attribute that can be attached to structured item entries
    public typealias Attribute = SentryAttribute

    /// The timestamp when the metric was recorded.
    public var timestamp: Date

    /// The type of metric (counter, gauge, or distribution).
    ///
    /// - `.counter`: Incrementing integer values (e.g., request counts)
    /// - `.gauge`: Current value at a point in time (e.g., active connections)
    /// - `.distribution`: Statistical distribution of values (e.g., response times)
    public let metricType: SentryMetricType

    /// The name of the metric (e.g., "api.response_time", "db.query.duration").
    ///
    /// Metric names should follow a dot-separated hierarchical naming convention
    /// to enable better organization and querying in Sentry.
    public var name: String

    /// The trace ID to associate this metric with distributed tracing.
    ///
    /// This will be set to a valid non-empty value during processing by the batcher,
    /// which applies scope-based attribute enrichment including trace context.
    public var traceId: SentryId

    /// The numeric value of the metric.
    ///
    /// The setter performs automatic type conversion when needed:
    /// - Setting a double on a counter: floors the value and converts to integer
    /// - Setting an integer on a gauge/distribution: converts to double
    ///
    /// - Note: Counters use integer values, distributions and gauges use double values.
    private var _value: SentryMetricValue
    public var value: SentryMetricValue {
        get {
            return _value
        }
        set {
            // Perform type conversion when needed
            switch (metricType, newValue) {
            case (.counter, .integer):
                _value = newValue
            case (.counter, .double(let doubleValue)):
                // Convert double to integer by flooring
                SentrySDKLog.warning("Attempted to set a double value (\(doubleValue)) on a counter metric. Converting to integer by flooring: \(Int64(floor(doubleValue))).")
                _value = .integer(Int64(floor(doubleValue)))
            case (.gauge, .double), (.distribution, .double):
                _value = newValue
            case (.gauge, .integer(let intValue)):
                // Convert integer to double
                SentrySDKLog.warning("Attempted to set an integer value (\(intValue)) on a gauge metric. Converting to double: \(Double(intValue)).")
                _value = .double(Double(intValue))
            case (.distribution, .integer(let intValue)):
                // Convert integer to double
                SentrySDKLog.warning("Attempted to set an integer value (\(intValue)) on a distribution metric. Converting to double: \(Double(intValue)).")
                _value = .double(Double(intValue))
            }
        }
    }
    
    /// The unit of measurement for the metric value (optional).
    ///
    /// Examples: "millisecond", "byte", "connection", "request". This helps
    /// provide context for the metric value when viewing in Sentry.
    public var unit: String?
    
    /// A dictionary of structured attributes added to the metric.
    ///
    /// Attributes provide additional context and can be used for filtering and
    /// grouping metrics in Sentry. Common attributes include endpoint names,
    /// HTTP methods, status codes, etc.
    public var attributes: [String: SentryAttribute]

    /// Creates a metric entry with the specified properties.
    ///
    /// - Note: This initializer is internal. Metrics should be created by the SDK through the public metrics API.
    ///         Users can modify metrics in the `beforeSendMetric` callback.
    ///
    /// - Parameters:
    ///   - timestamp: The timestamp when the metric was recorded
    ///   - traceId: The trace ID to associate this metric with distributed tracing
    ///   - name: The name of the metric
    ///   - value: The numeric value of the metric
    ///   - metricType: The type of metric
    ///   - unit: The unit of measurement for the metric value (optional)
    ///   - attributes: A dictionary of structured attributes to add to the metric
    internal init(
        timestamp: Date,
        traceId: SentryId,
        name: String,
        value: SentryMetricValue,
        type: SentryMetricType,
        unit: String?,
        attributes: [String: SentryAttribute]
    ) {
        self.timestamp = timestamp
        self.traceId = traceId
        self.name = name
        self.metricType = type
        self.unit = unit
        self.attributes = attributes
        
        // Perform type conversion when needed
        switch (type, value) {
        case (.counter, .integer), (.gauge, .double), (.distribution, .double):
            self._value = value
        case (.counter, .double(let doubleValue)):
            // Convert double to integer by flooring
            SentrySDKLog.warning("Counter metric created with double value \(doubleValue). Converting to integer by flooring: \(Int64(floor(doubleValue))).")
            self._value = .integer(Int64(floor(doubleValue)))
        case (.gauge, .integer(let intValue)):
            // Convert integer to double
            SentrySDKLog.warning("Gauge metric created with integer value \(intValue). Converting to double: \(Double(intValue)).")
            self._value = .double(Double(intValue))
        case (.distribution, .integer(let intValue)):
            // Convert integer to double
            SentrySDKLog.warning("Distribution metric created with integer value \(intValue). Converting to double: \(Double(intValue)).")
            self._value = .double(Double(intValue))
        }
    }
    
    /// Adds or updates an attribute in the metric entry.
    /// - Parameters:
    ///   - attribute: The attribute value to add
    ///   - key: The key for the attribute
    public mutating func setAttribute(_ attribute: SentryAttribute?, forKey key: String) {
        if let attribute = attribute {
            attributes[key] = attribute
        } else {
            attributes.removeValue(forKey: key)
        }
    }
}

extension SentryMetric: Encodable {
    private enum CodingKeys: String, CodingKey {
        case timestamp
        case traceId = "trace_id"
        case name
        case value
        case type
        case unit
        case attributes
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(traceId.sentryIdString, forKey: .traceId)
        try container.encode(name, forKey: .name)
        try container.encode(value, forKey: .value)
        
        try container.encode(metricType, forKey: .type)
        try container.encodeIfPresent(unit, forKey: .unit)
        try container.encode(attributes, forKey: .attributes)
    }
}

extension SentryMetric: BatcherItem {}

// MARK: - SentryMetricType

/// The type of metric being recorded.
///
/// Different metric types serve different purposes:
/// - **Counter**: Incrementing integer values that only increase (e.g., total requests, errors)
/// - **Gauge**: Current value at a point in time that can go up or down (e.g., active connections, queue size)
/// - **Distribution**: Statistical distribution of values for aggregation (e.g., response times, payload sizes)
public enum SentryMetricType: Encodable {
    /// Incrementing integer values that only increase.
    case counter
    
    /// Current value at a point in time that can fluctuate.
    case gauge
    
    /// Statistical distribution of values for aggregation.
    case distribution
    
    /// The string representation of the metric type for JSON encoding.
    var stringValue: String {
        switch self {
        case .counter:
            return "counter"
        case .gauge:
            return "gauge"
        case .distribution:
            return "distribution"
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let stringValue = try container.decode(String.self)
        switch stringValue {
        case "counter":
            self = .counter
        case "gauge":
            self = .gauge
        case "distribution":
            self = .distribution
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown metric type: \(stringValue)"
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(stringValue)
    }
}

// MARK: - SentryMetricValue

/// Represents the numeric value of a metric with type-safe distinction between integers and doubles.
///
/// This enum provides type safety to prevent accidentally mixing integer and floating-point values,
/// especially useful in `beforeSendMetric` callbacks where you need to ensure counters remain integers
/// and distributions remain doubles.
///
/// Per the metrics specification: "Integers should be a 64-bit signed integer, while doubles
/// should be a 64-bit floating point number."
///
/// The enum conforms to `ExpressibleByIntegerLiteral` and `ExpressibleByFloatLiteral`, allowing
/// convenient initialization:
/// ```swift
/// let counterValue: Metric.Value = 42        // Creates .integer(42)
/// let gaugeValue: Metric.Value = 3.14159     // Creates .double(3.14159)
/// ```
///
/// Example usage in `beforeSendMetric`:
/// ```swift
/// options.beforeSendMetric = { metric in
///     var modified = metric
///     switch modified.value {
///     case .integer(let intValue):
///         // Can safely modify as integer - e.g., for counters
///         modified.value = .integer(intValue + 1)
///         // Or use literal syntax: modified.value = intValue + 1
///     case .double(let doubleValue):
///         // Can safely modify as double - e.g., for distributions
///         modified.value = .double(doubleValue * 1.5)
///         // Or use literal syntax: modified.value = doubleValue * 1.5
///     }
///     return modified
/// }
/// ```
public enum SentryMetricValue: Encodable, Equatable, ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral, Hashable {
    /// A 64-bit signed integer value, typically used for counters.
    case integer(Int64)

    /// A 64-bit floating point value, typically used for distributions and gauges.
    case double(Double)

    /// Encodes the value according to the metrics specification.
    ///
    /// Integer values are encoded as `Int64` and double values as `Double` to ensure
    /// accurate representation in the metric payload.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .integer(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        }
    }

    /// Initializes a `Metric.Value` from a floating point literal.
    /// - Parameters:
    ///   - value: The floating point value to initialize the `Metric.Value` from
    public init(floatLiteral value: FloatLiteralType) {
        self = .double(value)
    }

    /// Initializes a `Metric.Value` from an integer literal.
    /// - Parameters:
    ///   - value: The integer value to initialize the `Metric.Value` from
    public init(integerLiteral value: IntegerLiteralType) {
        self = .integer(Int64(value))
    }
}
