import _SentryPrivate
import Foundation

public class TestTransport: NSObject, Transport {

    @_spi(Private) public var sentEnvelopes = Invocations<SentryEnvelope>()
    @_spi(Private) public func send(envelope: SentryEnvelope) {
        sentEnvelopes.record(envelope)
    }
    
    @_spi(Private) public var storedEnvelopes = Invocations<SentryEnvelope>()
    @_spi(Private) public func store(_ envelope: SentryEnvelope) {
        storedEnvelopes.record(envelope)
    }
    
    public var recordLostEvents = Invocations<(category: SentryDataCategory, reason: SentryDiscardReason)>()
    public func recordLostEvent(_ category: SentryDataCategory, reason: SentryDiscardReason) {
        recordLostEvents.record((category, reason))
    }
    
    public var recordLostEventsWithCount = Invocations<(category: SentryDataCategory, reason: SentryDiscardReason, quantity: UInt)>()
    public func recordLostEvent(_ category: SentryDataCategory, reason: SentryDiscardReason, quantity: UInt) {
        recordLostEventsWithCount.record((category, reason, quantity))
    }
    
    public var flushInvocations = Invocations<TimeInterval>()
    public func flush(_ timeout: TimeInterval) -> SentryFlushResult {
        flushInvocations.record(timeout)
        return .success
    }
    
    public func setStartFlushCallback(_ callback: @escaping () -> Void) {
        
    }
}
