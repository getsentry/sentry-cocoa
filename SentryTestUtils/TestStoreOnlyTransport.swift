import _SentryPrivate
import Foundation

public class TestStoreOnlyTransport: NSObject, Transport {
    public func send(envelope: SentryEnvelope) {
        
    }
    
    public func store(_ envelope: SentryEnvelope) {
    }
    
    public func recordLostEvent(_ category: SentryDataCategory, reason: SentryDiscardReason) {
    }
    
    public func recordLostEvent(_ category: SentryDataCategory, reason: SentryDiscardReason, quantity: UInt) {
    }
    
    public func flush(_ timeout: TimeInterval) -> SentryFlushResult {
        return .success
    }
    
    public func setStartFlushCallback(_ callback: @escaping () -> Void) {
    }
}
