/// A metric entry that captures metric data with associated attribute metadata.
///
/// Use the `options.beforeSendMetric` callback to modify or filter metric data.
public struct SentryMetric {
    /// A typed value of the metric
    public typealias Value = SentryMetricValue

    /// A typed attribute that can be attached to structured item entries
    public typealias Attribute = SentryAttributeContent

    /// A typed unit
    public typealias Unit = SentryUnit

    /// The timestamp when the metric was recorded.
    public var timestamp: Date

    /// The name of the metric (e.g., "api.response_time", "db.query.duration").
    ///
    /// Metric names should follow a dot-separated hierarchical naming convention
    /// to enable better organization and querying in Sentry.
    public var name: String

    /// The trace ID to associate this metric with distributed tracing.
    ///
    /// This will be set to a valid non-empty value during processing by the buffer,
    /// which applies scope-based attribute enrichment including trace context.
    public var traceId: SentryId

    /// The span ID is not used for metrics; exists to satisfy ``TelemetryItem`` conformance.
    public var spanId: SpanId?

    /// The numeric value of the metric.
    ///
    /// The setter performs automatic type conversion when needed:
    /// - Setting a double on a counter: floors the value and converts to integer
    /// - Setting an integer on a gauge/distribution: converts to double
    ///
    /// - Note: Counters use integer values, distributions and gauges use double values.
    public var value: Value

    /// The unit of measurement for the metric value (optional).
    ///
    /// Examples: "millisecond", "byte", "connection", "request". This helps
    /// provide context for the metric value when viewing in Sentry.
    public var unit: SentryUnit?

    /// A dictionary of structured attributes added to the metric.
    ///
    /// Attributes provide additional context and can be used for filtering and
    /// grouping metrics in Sentry. Common attributes include endpoint names,
    /// HTTP methods, status codes, etc.
    public var attributes: [String: Attribute]

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
    ///   - unit: The unit of measurement for the metric value (optional)
    ///   - attributes: A dictionary of structured attributes to add to the metric
    internal init(
        timestamp: Date,
        traceId: SentryId,
        name: String,
        value: SentryMetricValue,
        unit: SentryUnit?,
        attributes: [String: Attribute]
    ) {
        self.timestamp = timestamp
        self.traceId = traceId
        self.name = name
        self.unit = unit
        self.attributes = attributes
        self.value = value
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
    
    /// Encodes the metric to the given encoder.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(traceId.sentryIdString, forKey: .traceId)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(unit, forKey: .unit)
        try container.encode(attributes, forKey: .attributes)

        // We need to call the encode method instead of passing the value to the encoder
        // so that the `type` and `value` are set on the same level as the other keys.
        try value.encode(to: encoder)
    }
}

extension SentryMetric: TelemetryItem {
    var attributesDict: [String: SentryAttributeContent] {
        get {
            attributes
        }
        set {
            attributes = newValue
        }
    }
}
