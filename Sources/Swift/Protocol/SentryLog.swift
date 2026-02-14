/// A structured log entry that captures log data with associated attribute metadata.
///
/// Use the `options.beforeSendLog` callback to modify or filter log data.
@objcMembers
public final class SentryLog: NSObject {
    /// Alias for `SentryAttribute` to maintain backward compatibility after `SentryLog.Attribute` was renamed to `SentryAttribute`.
    public typealias Attribute = SentryAttribute

    /// The timestamp when the log event occurred
    public var timestamp: Date
    /// The trace ID to associate this log with distributed tracing. This will be set to a valid non-empty value during processing.
    public var traceId: SentryId
    /// The span ID of the span that was active when the log was collected.
    /// Only set when there is an active span; a propagated span_id must not be used.
    public var spanId: SpanId?
    /// The severity level of the log entry
    public var level: Level
    /// The main log message content
    public var body: String
    /// A dictionary of structured attributes added to the log entry
    public var attributes: [String: Attribute]
    /// Numeric representation of the severity level (Int)
    public var severityNumber: NSNumber?
    
    /// Creates a log entry with the specified level and message.
    /// - Parameters:
    ///   - level: The severity level of the log entry
    ///   - body: The main log message content
    @objc public convenience init(
        level: Level,
        body: String
    ) {
        self.init(
            timestamp: Date(),
            traceId: SentryId.empty,
            level: level,
            body: body,
            attributes: [:]
        )
    }
    
    /// Creates a log entry with the specified level, message, and attributes.
    /// - Parameters:
    ///   - level: The severity level of the log entry
    ///   - body: The main log message content
    ///   - attributes: A dictionary of structured attributes to add to the log entry
    @objc public convenience init(
        level: Level,
        body: String,
        attributes: [String: Attribute]
    ) {
        self.init(
            timestamp: Date(),
            traceId: SentryId.empty,
            level: level,
            body: body,
            attributes: attributes
        )
    }
    
    internal init(
        timestamp: Date,
        traceId: SentryId,
        spanId: SpanId? = nil,
        level: Level,
        body: String,
        attributes: [String: Attribute],
        severityNumber: NSNumber? = nil
    ) {
        self.timestamp = timestamp
        self.traceId = traceId
        self.spanId = spanId
        self.level = level
        self.body = body
        self.attributes = attributes
        self.severityNumber = severityNumber ?? NSNumber(value: level.toSeverityNumber())
        super.init()
    }
    
    /// Adds or updates an attribute in the log entry.
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

// MARK: - TelemetryItem Conformance
extension SentryLog: TelemetryItem {
    var attributesDict: [String: SentryAttributeContent] {
        get {
            attributes.mapValues { value in
                SentryAttributeContent.from(anyValue: value)
            }
        }
        set {
            attributes = newValue.mapValues { value in
                SentryAttribute(attributableValue: value)
            }
        }
    }
}

// MARK: - Internal Encodable Support
@_spi(Private) extension SentryLog: Encodable {
    private enum CodingKeys: String, CodingKey {
        case timestamp
        case traceId = "trace_id"
        case spanId = "span_id"
        case level
        case body
        case attributes
        case severityNumber = "severity_number"
    }
    
    /// nodoc
    @_spi(Private) public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(traceId.sentryIdString, forKey: .traceId)
        try container.encodeIfPresent(spanId?.sentrySpanIdString, forKey: .spanId)
        try container.encode(level, forKey: .level)
        try container.encode(body, forKey: .body)
        try container.encode(attributes, forKey: .attributes)
        try container.encodeIfPresent(severityNumber?.intValue, forKey: .severityNumber)
    }
}
