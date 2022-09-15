import Foundation

@objc
public class TestTransport: NSObject, Transport {
    
    var sentEnvelopes = Invocations<SentryEnvelope>()
    public func send(envelope: SentryEnvelope) {
        sentEnvelopes.record(envelope)
    }
    
    var recordLostEvents = Invocations<(category: SentryDataCategory, reason: SentryDiscardReason)>()
    public func recordLostEvent(_ category: SentryDataCategory, reason: SentryDiscardReason) {
        recordLostEvents.record((category, reason))
    }
    
    var flushInvocations = Invocations<TimeInterval>()
    public func flush(_ timeout: TimeInterval) -> Bool {
        flushInvocations.record(timeout)
        return true
    }
}
