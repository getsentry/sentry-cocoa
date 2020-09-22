import Foundation

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
    
    var sentCrashEvents: [Event] = []
    override func captureCrash(_ event: Event) {
        sentCrashEvents.append(event)
    }
}
