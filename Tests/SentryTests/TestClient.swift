import Foundation

class TestClient: Client {
    var sentryFileManager: SentryFileManager = try! SentryFileManager(dsn: SentryDsn(), andCurrentDateProvider: TestCurrentDateProvider())
    override func fileManager() -> SentryFileManager {
        sentryFileManager
    }
    
    var sessions: [SentrySession] = []
    override func capture(session: SentrySession) {
        sessions.append(session)
    }
    
    var events: [Event] = []
    override func capture(event: Event, scope: Scope?) -> SentryId {
        events.append(event)
        return event.eventId
    }
}

class TestFileManager: SentryFileManager {
    var timestampLastInForeground: Date?
    var readTimestampLastInForegroundInvocations: Int = 0
    var storeTimestampLastInForegroundInvocations: Int = 0
    var deleteTimestampLastInForegroundInvocations: Int = 0

    override func readTimestampLastInForeground() -> Date? {
        readTimestampLastInForegroundInvocations += 1
        return timestampLastInForeground
    }

    override func storeTimestampLast(inForeground: Date) {
        storeTimestampLastInForegroundInvocations += 1
        timestampLastInForeground = inForeground
    }

    override func deleteTimestampLastInForeground() {
        deleteTimestampLastInForegroundInvocations += 1
        timestampLastInForeground = nil
    }
    
}
