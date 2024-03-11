import _SentryPrivate
import Foundation
import SentryTestUtils

class TestHub: SentryHub {

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
    
    var sentCrashEvents = Invocations<Event>()
    override func captureCrash(_ event: Event) {
        sentCrashEvents.record(event)
    }
    
    var sentCrashEventsWithScope = Invocations<(event: Event, scope: Scope)>()
    override func captureCrash(_ event: Event, with scope: Scope) {
        sentCrashEventsWithScope.record((event, scope))
    }
    
    var capturedEventsWithScopes = Invocations<(event: Event, scope: Scope, additionalEnvelopeItems: [SentryEnvelopeItem])>()
    override func capture(event: Event, scope: Scope, additionalEnvelopeItems: [SentryEnvelopeItem]) -> SentryId {
        
        self.capturedEventsWithScopes.record((event, scope, additionalEnvelopeItems))
        
        return event.eventId
    }

    var capturedTransactionsWithScope = Invocations<(transaction: [String: Any], scope: Scope)>()
    override func capture(_ transaction: Transaction, with scope: Scope) -> SentryId {
        capturedTransactionsWithScope.record((transaction.serialize(), scope))
        return super.capture(transaction, with: scope)
    }
}
