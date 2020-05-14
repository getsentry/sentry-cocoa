import Foundation

class TestHub: SentryHub {

    var startSessionInvocations: Int = 0
    var closeCachedSessionInvocations: Int = 0
    var endSessionTimestamp: Date?

    override func startSession() {
        startSessionInvocations += 1
    }

    override func closeCachedSession() {
        closeCachedSessionInvocations += 1
    }

    override func endSession(withTimestamp timestamp: Date) {
        endSessionTimestamp = timestamp
    }
}
