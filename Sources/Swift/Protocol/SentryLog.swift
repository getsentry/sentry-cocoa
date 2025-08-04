/// A structured log entry that captures log data with associated attribute metadata.
///
/// Use the `options.beforeSendLog` callback to modify or filter log data.
@objc
@objcMembers
public class SentryLog: NSObject, Codable {
    /// The timestamp when the log event occurred
    public var timestamp: Date
    /// The trace ID to associate this log with distributed tracing
    public var traceId: SentryId
    /// The severity level of the log entry
    public var level: Level
    /// The main log message content
    public var body: String
    /// A dictionary of structured attributes added to the log entry
    public var attributes: [String: Attribute]
    /// Numeric representation of the severity level (Int)
    public var severityNumber: NSNumber?
    
    private enum CodingKeys: String, CodingKey {
        case timestamp
        case traceId = "trace_id"
        case level
        case body
        case attributes
        case severityNumber = "severity_number"
    }
    
    internal init(
        timestamp: Date,
        traceId: SentryId,
        level: Level,
        body: String,
        attributes: [String: Attribute],
        severityNumber: NSNumber? = nil
    ) {
        self.timestamp = timestamp
        self.traceId = traceId
        self.level = level
        self.body = body
        self.attributes = attributes
        self.severityNumber = severityNumber ?? NSNumber(value: level.toSeverityNumber())
        super.init()
    }
    
    required public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        let traceIdString = try container.decode(String.self, forKey: .traceId)
        traceId = SentryId(uuidString: traceIdString)
        level = try container.decode(Level.self, forKey: .level)
        body = try container.decode(String.self, forKey: .body)
        attributes = try container.decode([String: Attribute].self, forKey: .attributes)
        severityNumber = try container.decodeIfPresent(Int.self, forKey: .severityNumber).map { NSNumber(value: $0) }
        
        super.init()
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(traceId.sentryIdString, forKey: .traceId)
        try container.encode(level, forKey: .level)
        try container.encode(body, forKey: .body)
        try container.encode(attributes, forKey: .attributes)
        try container.encodeIfPresent(severityNumber?.intValue, forKey: .severityNumber)
    }
}
