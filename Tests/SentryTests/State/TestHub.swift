import Foundation

class TestHub: SentryHub {
    
    let group = DispatchGroup()
    let queue = DispatchQueue(label: "TestHub", attributes: .concurrent)

    var startSessionInvocations: Int = 0
    var closeCachedSessionInvocations: Int = 0
    var endSessionTimestamp: Date?
    var closeCachedSessionTimestamp: Date?

    override func startSession() {
        startSessionInvocations += 1
    }

    override func closeCachedSession(withTimestamp timestamp: Date?) {
        closeCachedSessionTimestamp = timestamp
        closeCachedSessionInvocations += 1
    }
    
    override func endSession(withTimestamp timestamp: Date) {
        endSessionTimestamp = timestamp
    }
    
    var sentCrashEvents: [Event] = []
    override func captureCrash(_ event: Event) {
        sentCrashEvents.append(event)
    }
    
    var capturedEventsWithScopes: [(event: Event, scope: Scope, additionalEnvelopeItems: [SentryEnvelopeItem])] = []
    override func capture(event: Event, scope: Scope) -> SentryId {
        group.enter()
        queue.async(flags: .barrier) {
            self.capturedEventsWithScopes.append((event, scope, []))
            self.group.leave()
        }
        
        return event.eventId
    }
    
    override func capture(event: Event, scope: Scope, additionalEnvelopeItems: [SentryEnvelopeItem]) -> SentryId {
        group.enter()
        queue.async(flags: .barrier) {
            self.capturedEventsWithScopes.append((event, scope, additionalEnvelopeItems))
            self.group.leave()
        }
        
        return event.eventId
    }
    
    var capturedTransactionsWithScopes: [(transaction: Transaction, scope: Scope, additionalEnvelopeItems: [SentryEnvelopeItem])] = []
    override func capture(_ transaction: Transaction, with scope: Scope, additionalEnvelopeItems: [SentryEnvelopeItem]) -> SentryId {
        group.enter()
        queue.async(flags: .barrier) {
            self.capturedTransactionsWithScopes.append((transaction, scope, additionalEnvelopeItems))
            self.group.leave()
        }
        
        return transaction.eventId
    }
}
