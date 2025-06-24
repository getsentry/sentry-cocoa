struct SentryLog {
    let timestamp: Date
    var traceId: SentryId
    let level: SentryLog.Level
    let body: String
    let attributes: [String: SentryLogAttribute]
    let severityNumber: Int?
    
    /// The traceId is initially an empty default value and is populated during processing;
    /// by the time processing completes, it is guaranteed to be a valid non-empty trace id.
    init(
        timestamp: Date,
        traceId: SentryId? = nil,
        level: SentryLog.Level,
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
