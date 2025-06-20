@objcMembers
public final class SentryLog {
    public let timestamp: Date
    public var traceId: SentryId
    public let level: SentryLogLevel
    public let body: String
    public let attributes: [String: SentryLogAttribute]
    public let severityNumber: Int?
    
    /// The traceId is initially an empty default value and is populated during processing;
    /// by the time processing completes, it is guaranteed to be a valid non-empty trace id.
    public init(
        timestamp: Date,
        traceId: SentryId? = nil,
        level: SentryLogLevel,
        body: String,
        attributes: [String: SentryLogAttribute],
        severityNumber: Int? = nil
    ) {
        self.timestamp = timestamp
        self.traceId = traceId ?? SentryId.empty
        self.level = level
        self.body = body
        self.attributes = attributes
        self.severityNumber = severityNumber
    }
}
