/**
 * A mutable wrapper for use in `beforeSendLog` callbacks.
 *
 * The internal log structure is immutable for thread safety and data integrity in the SDK pipeline.
 * `MutableSentryLog` provides a mutable interface for user modifications in callbacks.
 */
@objcMembers
public class MutableSentryLog: NSObject {
    
    public var timestamp: Date
    public var traceId: SentryId
    public var level: MutableSentryLogLevel {
        didSet {
            // Automatically update severity number when level changes
            self.severityNumber = NSNumber(value: level.toSeverityNumber())
        }
    }
    public var body: String
    public var attributes: [String: Any]
    public var severityNumber: NSNumber?
    
    init(log: SentryLog) {
        self.timestamp = log.timestamp
        self.traceId = log.traceId
        self.level = MutableSentryLogLevel.from(log.level)
        self.body = log.body
        self.attributes = log.attributes.mapValues { $0.value }
        self.severityNumber = log.severityNumber.map { NSNumber(value: $0) }
        super.init()
    }
    
    func toSentryLog() -> SentryLog {
        let sentryAttributes = attributes.mapValues { SentryLog.Attribute(value: $0) }
        
        return SentryLog(
            timestamp: timestamp,
            traceId: traceId,
            level: level.toLevel(),
            body: body,
            attributes: sentryAttributes,
            severityNumber: severityNumber?.intValue
        )
    }
}
