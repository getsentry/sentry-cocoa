import Foundation

@objc
public final class SentryLog: NSObject, Codable {
    let timestamp: Date
    var traceId: SentryId
    let level: SentryLog.Level
    let body: String
    let attributes: [String: SentryLog.Attribute]
    let severityNumber: Int?
    
    private enum CodingKeys: String, CodingKey {
        case timestamp
        case traceId = "trace_id"
        case level
        case body
        case attributes
        case severityNumber = "severity_number"
    }
    
    /// The traceId is initially an empty default value and is populated during processing;
    /// by the time processing completes, it is guaranteed to be a valid non-empty trace id.
    init(
        timestamp: Date,
        traceId: SentryId? = nil,
        level: SentryLog.Level,
        body: String,
        attributes: [String: SentryLog.Attribute],
        severityNumber: Int? = nil
    ) {
        self.timestamp = timestamp
        self.traceId = traceId ?? SentryId.empty
        self.level = level
        self.body = body
        self.attributes = attributes
        self.severityNumber = severityNumber
        super.init()
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        let traceIdString = try container.decode(String.self, forKey: .traceId)
        self.traceId = SentryId(uuidString: traceIdString)
        self.level = try container.decode(SentryLog.Level.self, forKey: .level)
        self.body = try container.decode(String.self, forKey: .body)
        self.attributes = try container.decode([String: SentryLog.Attribute].self, forKey: .attributes)
        self.severityNumber = try container.decodeIfPresent(Int.self, forKey: .severityNumber)
        
        super.init()
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(traceId.sentryIdString, forKey: .traceId)
        try container.encode(level, forKey: .level)
        try container.encode(body, forKey: .body)
        try container.encode(attributes, forKey: .attributes)
        try container.encodeIfPresent(severityNumber, forKey: .severityNumber)
    }
}
