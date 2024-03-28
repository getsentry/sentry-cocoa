import _SentryPrivate
import Foundation

@objc
public class TestTransport: NSObject, Transport {
    
    public var sentEnvelopes = Invocations<SentryEnvelope>()
    public func send(envelope: SentryEnvelope) {
        sentEnvelopes.record(envelope)
    }
    
    public var recordLostEvents = Invocations<(category: SentryDataCategory, reason: SentryDiscardReason)>()
    public func recordLostEvent(_ category: SentryDataCategory, reason: SentryDiscardReason) {
        recordLostEvents.record((category, reason))
    }
    
    public var flushInvocations = Invocations<TimeInterval>()
    public func flush(_ timeout: TimeInterval) -> SentryFlushResult {
        flushInvocations.record(timeout)
        return .success
    }
    
    public func setStartFlushCallback(_ callback: @escaping () -> Void) {
        
    }
}
