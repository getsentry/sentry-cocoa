import Foundation

class TestClient: Client {
    
    let sentryFileManager: SentryFileManager
    
    override init?(options: Options) {
        sentryFileManager = try! SentryFileManager(options: options, andCurrentDateProvider: TestCurrentDateProvider())
        super.init(options: options)
    }
    
    override func fileManager() -> SentryFileManager {
        sentryFileManager
    }
    
    var sessions: [SentrySession] = []
    override func capture(session: SentrySession) {
        sessions.append(session)
    }
    
    var captureEventArguments: [Event] = []
    override func capture(event: Event) -> SentryId {
        captureEventArguments.append(event)
        return event.eventId
    }
    
    var captureEventWithScopeArguments: [(event: Event, scope: Scope)] = []
    override func capture(event: Event, scope: Scope) -> SentryId {
        captureEventWithScopeArguments.append((event, scope))
        return event.eventId
    }
    
    var captureMessageArguments: [String] = []
    override func capture(message: String) -> SentryId {
        captureMessageArguments.append(message)
        return SentryId()
    }
    
    var captureMessageWithScopeArguments: [(message: String, scope: Scope)] = []
    override func capture(message: String, scope: Scope) -> SentryId {
        captureMessageWithScopeArguments.append((message, scope))
        return SentryId()
    }
    
    var captureErrorArguments: [Error] = []
    override func capture(error: Error) -> SentryId {
        captureErrorArguments.append(error)
        return SentryId()
    }
    
    var captureErrorWithScopeArguments: [(error: Error, scope: Scope)] = []
    override func capture(error: Error, scope: Scope) -> SentryId {
        captureErrorWithScopeArguments.append((error, scope))
        return SentryId()
    }
    
    var captureExceptionArguments: [NSException] = []
    override func capture(exception: NSException) -> SentryId {
        captureExceptionArguments.append(exception)
        return SentryId()
    }
    
    var captureExceptionWithScopeArguments: [(exception: NSException, scope: Scope)] = []
    override func capture(exception: NSException, scope: Scope) -> SentryId {
        captureExceptionWithScopeArguments.append((exception, scope))
        return SentryId()
    }
    
    var captureErrorWithSessionArguments: [(error: Error, session: SentrySession, scope: Scope)] = []
    override func captureError(_ error: Error, with session: SentrySession, with scope: Scope) -> SentryId {
        captureErrorWithSessionArguments.append((error, session, scope))
               return SentryId()
    }
    
    var captureExceptionWithSessionArguments: [(exception: NSException, session: SentrySession, scope: Scope)] = []
    override func capture(_ exception: NSException, with session: SentrySession, with scope: Scope) -> SentryId {
        captureExceptionWithSessionArguments.append((exception, session, scope))
        return SentryId()
    }
    
    var captureCrashEventArguments: [(event: Event, scope: Scope)] = []
    override func captureCrash(_ event: Event, with scope: Scope) -> SentryId {
        captureCrashEventArguments.append((event, scope))
        return SentryId()
    }
    
    var captureCrashEventWithSessionArguments: [(event: Event, session: SentrySession, scope: Scope)] = []
    override func captureCrash(_ event: Event, with session: SentrySession, with scope: Scope) -> SentryId {
        captureCrashEventWithSessionArguments.append((event, session, scope))
        return SentryId()
    }
    
    var capturedUserFeedback: [UserFeedback] = []
    override func capture(userFeedback: UserFeedback) {
        capturedUserFeedback.append(userFeedback)
    }
    
    var capturedEnvelopes: [SentryEnvelope] = []
    override func capture(envelope: SentryEnvelope) {
        capturedEnvelopes.append(envelope)
    }
    
    var storedEnvelopes: [SentryEnvelope] = []
    override func store(_ envelope: SentryEnvelope) {
        storedEnvelopes.append(envelope)
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
