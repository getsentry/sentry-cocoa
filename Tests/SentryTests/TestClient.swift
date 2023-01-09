import Foundation

class TestClient: SentryClient {
    override init?(options: Options) {
        super.init(options: options, fileManager: try! TestFileManager(options: options))
    }

    override init?(options: Options, fileManager: SentryFileManager) {
        super.init(options: options, fileManager: fileManager)
    }
    
    // Without this override we get a fatal error: use of unimplemented initializer
    // see https://stackoverflow.com/questions/28187261/ios-swift-fatal-error-use-of-unimplemented-initializer-init
    override init(options: Options, transportAdapter: SentryTransportAdapter, fileManager: SentryFileManager, threadInspector: SentryThreadInspector, random: SentryRandomProtocol, crashWrapper: SentryCrashWrapper, deviceWrapper: SentryUIDeviceWrapper, locale: Locale, timezone: TimeZone) {
        super.init(
            options: options,
            transportAdapter: transportAdapter,
            fileManager: fileManager,
            threadInspector: threadInspector,
            random: random,
            crashWrapper: crashWrapper,
            deviceWrapper: deviceWrapper,
            locale: locale,
            timezone: timezone
        )
    }
    
    var captureSessionInvocations = Invocations<SentrySession>()
    override func capture(session: SentrySession) {
        captureSessionInvocations.record(session)
    }
    
    var captureEventInvocations = Invocations<Event>()
    override func capture(event: Event) -> SentryId {
        captureEventInvocations.record(event)
        return event.eventId
    }
    
    var captureEventWithScopeInvocations = Invocations<(event: Event, scope: Scope, additionalEnvelopeItems: [SentryEnvelopeItem])>()
    override func capture(event: Event, scope: Scope, additionalEnvelopeItems: [SentryEnvelopeItem]) -> SentryId {
        captureEventWithScopeInvocations.record((event, scope, additionalEnvelopeItems))
        return event.eventId
    }
    
    var captureMessageInvocations = Invocations<String>()
    override func capture(message: String) -> SentryId {
        self.captureMessageInvocations.record(message)
        return SentryId()
    }
    
    var captureMessageWithScopeInvocations = Invocations<(message: String, scope: Scope)>()
    override func capture(message: String, scope: Scope) -> SentryId {
        captureMessageWithScopeInvocations.record((message, scope))
        return SentryId()
    }
    
    var captureErrorInvocations = Invocations<Error>()
    override func capture(error: Error) -> SentryId {
        captureErrorInvocations.record(error)
        return SentryId()
    }
    
    var captureErrorWithScopeInvocations = Invocations<(error: Error, scope: Scope)>()
    override func capture(error: Error, scope: Scope) -> SentryId {
        captureErrorWithScopeInvocations.record((error, scope))
        return SentryId()
    }
    
    var captureExceptionInvocations = Invocations<NSException>()
    override func capture(exception: NSException) -> SentryId {
        captureExceptionInvocations.record(exception)
        return SentryId()
    }
    
    var captureExceptionWithScopeInvocations = Invocations<(exception: NSException, scope: Scope)>()
    override func capture(exception: NSException, scope: Scope) -> SentryId {
        captureExceptionWithScopeInvocations.record((exception, scope))
        return SentryId()
    }

    var callSessionBlockWithIncrementSessionErrors = true
    var captureErrorWithSessionInvocations = Invocations<(error: Error, session: SentrySession?, scope: Scope)>()
    override func captureError(_ error: Error, with scope: Scope, incrementSessionErrors sessionBlock: @escaping () -> SentrySession) -> SentryId {
        captureErrorWithSessionInvocations.record((error, callSessionBlockWithIncrementSessionErrors ? sessionBlock() : nil, scope))
        return SentryId()
    }
    
    var captureExceptionWithSessionInvocations = Invocations<(exception: NSException, session: SentrySession?, scope: Scope)>()
    override func capture(_ exception: NSException, with scope: Scope, incrementSessionErrors sessionBlock: @escaping () -> SentrySession) -> SentryId {
        captureExceptionWithSessionInvocations.record((exception, callSessionBlockWithIncrementSessionErrors ? sessionBlock() : nil, scope))
        return SentryId()
    }
    
    var captureCrashEventInvocations = Invocations<(event: Event, scope: Scope)>()
    override func captureCrash(_ event: Event, with scope: Scope) -> SentryId {
        captureCrashEventInvocations.record((event, scope))
        return SentryId()
    }
    
    var captureCrashEventWithSessionInvocations = Invocations<(event: Event, session: SentrySession, scope: Scope)>()
    override func captureCrash(_ event: Event, with session: SentrySession, with scope: Scope) -> SentryId {
        captureCrashEventWithSessionInvocations.record((event, session, scope))
        return SentryId()
    }
    
    var captureUserFeedbackInvocations = Invocations<UserFeedback>()
    override func capture(userFeedback: UserFeedback) {
        captureUserFeedbackInvocations.record(userFeedback)
    }
    
    var captureEnvelopeInvocations = Invocations<SentryEnvelope>()
    override func capture(envelope: SentryEnvelope) {
        captureEnvelopeInvocations.record(envelope)
    }
    
    var storedEnvelopeInvocations = Invocations<SentryEnvelope>()
    override func store(_ envelope: SentryEnvelope) {
        storedEnvelopeInvocations.record(envelope)
    }
    
    var recordLostEvents = Invocations<(category: SentryDataCategory, reason: SentryDiscardReason)>()
    override func recordLostEvent(_ category: SentryDataCategory, reason: SentryDiscardReason) {
        recordLostEvents.record((category, reason))
    }
    
    var flushInvocations = Invocations<TimeInterval>()
    override func flush(timeout: TimeInterval) {
        flushInvocations.record(timeout)
    }
}

class TestFileManager: SentryFileManager {
    var timestampLastInForeground: Date?
    var readTimestampLastInForegroundInvocations: Int = 0
    var storeTimestampLastInForegroundInvocations: Int = 0
    var deleteTimestampLastInForegroundInvocations: Int = 0

    init(options: Options) throws {
        try super.init(options: options, andCurrentDateProvider: TestCurrentDateProvider(), dispatchQueueWrapper: TestSentryDispatchQueueWrapper())
    }

    init(options: Options, andCurrentDateProvider currentDateProvider: CurrentDateProvider) throws {
        try super.init(options: options, andCurrentDateProvider: currentDateProvider, dispatchQueueWrapper: TestSentryDispatchQueueWrapper())
    }

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
    
    var readAppStateInvocations = Invocations<Void>()
    override func readAppState() -> SentryAppState? {
        readAppStateInvocations.record(Void())
        return nil
    }

    var readPreviousAppStateInvocations = Invocations<Void>()
    override func readPreviousAppState() -> SentryAppState? {
        readPreviousAppStateInvocations.record(Void())
        return nil
    }
}
