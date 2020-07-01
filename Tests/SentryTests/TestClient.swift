import Foundation

class TestClient: Client {
    var sentryFileManager: SentryFileManager = try! SentryFileManager(dsn: SentryDsn())
    override func fileManager() -> SentryFileManager {
        sentryFileManager
    }
    
    var sessions : [SentrySession] = []
    override func capture(session: SentrySession) {
        sessions.append(session)
    }
}

class TestFileManager: SentryFileManager {
    var timestampLastInForeground: Date? = Date()
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
