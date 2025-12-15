/// A metric entry that captures metric data with associated attribute metadata.
///
/// Use the `options.beforeSendMetric` callback to modify or filter metric data.
@objc
@objcMembers
public final class SentryMetric: NSObject {
    /// The timestamp when the metric was recorded
    public var timestamp: Date
    /// The trace ID to associate this metric with distributed tracing. This will be set to a valid non-empty value during processing.
    public var traceId: SentryId
    /// The span ID of the span that was active when the metric was emitted (optional)
    public var spanId: SpanId?
    /// The name of the metric (e.g., "api.response_time", "db.query.duration")
    public var name: String
    /// The numeric value of the metric
    public var value: NSNumber
    /// The type of metric (counter, gauge, or distribution)
    public var type: MetricType
    /// The unit of measurement for the metric value (optional)
    public var unit: String?
    /// A dictionary of structured attributes added to the metric
    public var attributes: [String: Attribute]
    
    /// Creates a metric entry with the specified properties.
    /// - Parameters:
    ///   - timestamp: The timestamp when the metric was recorded
    ///   - traceId: The trace ID to associate this metric with distributed tracing
    ///   - spanId: The span ID of the span that was active when the metric was emitted (optional)
    ///   - name: The name of the metric
    ///   - value: The numeric value of the metric
    ///   - type: The type of metric
    ///   - unit: The unit of measurement for the metric value (optional)
    ///   - attributes: A dictionary of structured attributes to add to the metric
    @objc public init(
        timestamp: Date,
        traceId: SentryId,
        spanId: SpanId?,
        name: String,
        value: NSNumber,
        type: MetricType,
        unit: String?,
        attributes: [String: Attribute]
    ) {
        self.timestamp = timestamp
        self.traceId = traceId
        self.spanId = spanId
        self.name = name
        self.value = value
        self.type = type
        self.unit = unit
        self.attributes = attributes
        super.init()
    }
    
    /// Adds or updates an attribute in the metric entry.
    /// - Parameters:
    ///   - attribute: The attribute value to add
    ///   - key: The key for the attribute
    @objc public func setAttribute(_ attribute: Attribute?, forKey key: String) {
        if let attribute = attribute {
            attributes[key] = attribute
        } else {
            attributes.removeValue(forKey: key)
        }
    }
}

/// The type of metric being recorded.
@objc
public enum MetricType: Int, Codable {
    case counter = 0
    case gauge = 1
    case distribution = 2
    
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

extension SentryMetric {
    /// A typed attribute that can be attached to metric entries.
    ///
    /// `Attribute` provides a type-safe way to store structured data alongside metrics.
    /// Supports String, Bool, Int, and Double types.
    /// Reuses the same Attribute type as SentryLog for consistency.
    public typealias Attribute = SentryLog.Attribute
}

// MARK: - Internal Codable Support
@_spi(Private) extension SentryMetric: Encodable {
    private enum CodingKeys: String, CodingKey {
        case timestamp
        case traceId = "trace_id"
        case spanId = "span_id"
        case name
        case value
        case type
        case unit
        case attributes
    }
    
//    @_spi(Private) public convenience init(from decoder: any Decoder) throws {
//        let container = try decoder.container(keyedBy: CodingKeys.self)
//        
//        let timestamp = try container.decode(Date.self, forKey: .timestamp)
//        let traceIdString = try container.decode(String.self, forKey: .traceId)
//        let traceId = SentryId(uuidString: traceIdString)
//        let spanIdString = try container.decodeIfPresent(String.self, forKey: .spanId)
//        let spanId = spanIdString.map { SpanId(value: $0) }
//        let name = try container.decode(String.self, forKey: .name)
//        
//        // Decode value - can be Int or Double
//        let value: NSNumber
//        if let intValue = try? container.decode(Int64.self, forKey: .value) {
//            value = NSNumber(value: intValue)
//        } else if let doubleValue = try? container.decode(Double.self, forKey: .value) {
//            value = NSNumber(value: doubleValue)
//        } else {
//            throw DecodingError.typeMismatch(
//                NSNumber.self,
//                DecodingError.Context(
//                    codingPath: decoder.codingPath + [CodingKeys.value],
//                    debugDescription: "Expected Int64 or Double for value"
//                )
//            )
//        }
//        
//        let type = try container.decode(MetricType.self, forKey: .type)
//        let unit = try container.decodeIfPresent(String.self, forKey: .unit)
//        let attributes = try container.decode([String: Attribute].self, forKey: .attributes)
//        
//        self.init(
//            timestamp: timestamp,
//            traceId: traceId,
//            spanId: spanId,
//            name: name,
//            value: value,
//            type: type,
//            unit: unit,
//            attributes: attributes
//        )
//    }
    
    @_spi(Private) public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(traceId.sentryIdString, forKey: .traceId)
        try container.encodeIfPresent(spanId?.sentrySpanIdString, forKey: .spanId)
        try container.encode(name, forKey: .name)
        
        // Encode value as Int64 or Double based on the underlying type
        // Check if it's an integer type by comparing the double value
        let doubleValue = value.doubleValue
        let int64Value = value.int64Value
        
        // If the double representation equals the int64 representation, encode as Int64
        // Otherwise encode as Double
        if abs(doubleValue - Double(int64Value)) < 0.0001 && type == .counter {
            try container.encode(int64Value, forKey: .value)
        } else {
            try container.encode(doubleValue, forKey: .value)
        }
        
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(unit, forKey: .unit)
        try container.encode(attributes, forKey: .attributes)
    }
}
