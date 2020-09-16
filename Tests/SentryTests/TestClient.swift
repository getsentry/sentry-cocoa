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
    
    var captureEventArguments: [Pair<Event, Scope?>] = []
    override func capture(event: Event, scope: Scope?) -> SentryId {
        captureEventArguments.append(Pair(event, scope))
        return event.eventId
    }
    
    var captureMessageArguments: [Pair<String, Scope?>] = []
    override func capture(message: String, scope: Scope?) -> SentryId {
        captureMessageArguments.append(Pair(message, scope))
        return SentryId()
    }
    
    var captureErrorArguments: [Pair<Error, Scope?>] = []
    override func capture(error: Error, scope: Scope?) -> SentryId {
        captureErrorArguments.append(Pair(error, scope))
        return SentryId()
    }
    
    var captureExceptionArguments: [Pair<NSException, Scope?>] = []
    override func capture(exception: NSException, scope: Scope?) -> SentryId {
        captureExceptionArguments.append(Pair(exception, scope))
        return SentryId()
    }
    
    var captureErrorWithSessionArguments: [Triple<Error, SentrySession, Scope?>] = []
    override func captureError(_ error: Error, with session: SentrySession, with scope: Scope?) -> SentryId {
        captureErrorWithSessionArguments.append(Triple(error, session, scope))
               return SentryId()
    }
    
    var captureExceptionWithSessionArguments: [Triple<NSException, SentrySession, Scope?>] = []
    override func capture(_ exception: NSException, with session: SentrySession, with scope: Scope?) -> SentryId {
        captureExceptionWithSessionArguments.append(Triple(exception, session, scope))
        return SentryId()
    }
    
    var captureEventWithSessionArguments: [Triple<Event, SentrySession, Scope?>] = []
    override func capture(_ event: Event, with session: SentrySession, with scope: Scope?) -> SentryId {
        captureEventWithSessionArguments.append(Triple(event, session, scope))
        return SentryId()
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
