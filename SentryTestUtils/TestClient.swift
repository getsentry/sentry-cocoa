import Foundation

public class TestClient: SentryClient {
    public override init?(options: Options) {
        super.init(options: options, fileManager: try! TestFileManager(options: options), deleteOldEnvelopeItems: false, transportAdapter: TestTransportAdapter(transport: TestTransport(), options: options))
    }

    public override init?(options: Options, fileManager: SentryFileManager, deleteOldEnvelopeItems: Bool) {
        super.init(options: options, fileManager: fileManager, deleteOldEnvelopeItems: deleteOldEnvelopeItems, transportAdapter: TestTransportAdapter(transport: TestTransport(), options: options))
    }
    
    public override init(options: Options, fileManager: SentryFileManager, deleteOldEnvelopeItems: Bool, transportAdapter: SentryTransportAdapter) {
        super.init(options: options, fileManager: fileManager, deleteOldEnvelopeItems: deleteOldEnvelopeItems, transportAdapter: transportAdapter)
    }
    
    // Without this override we get a fatal error: use of unimplemented initializer
    // see https://stackoverflow.com/questions/28187261/ios-swift-fatal-error-use-of-unimplemented-initializer-init
    public override init(options: Options, transportAdapter: SentryTransportAdapter, fileManager: SentryFileManager, deleteOldEnvelopeItems: Bool, threadInspector: SentryThreadInspector, random: SentryRandomProtocol, locale: Locale, timezone: TimeZone, extraContextProvider: SentryExtraContextProvider) {
        super.init(
            options: options,
            transportAdapter: transportAdapter,
            fileManager: fileManager,
            deleteOldEnvelopeItems: false,
            threadInspector: threadInspector,
            random: random,
            locale: locale,
            timezone: timezone,
            extraContextProvider: extraContextProvider
        )
    }
    
    public var captureSessionInvocations = Invocations<SentrySession>()
    public override func capture(session: SentrySession) {
        captureSessionInvocations.record(session)
    }
    
    public var captureEventInvocations = Invocations<Event>()
    public override func capture(event: Event) -> SentryId {
        captureEventInvocations.record(event)
        return event.eventId
    }
    
    public var captureEventWithScopeInvocations = Invocations<(event: Event, scope: Scope, additionalEnvelopeItems: [SentryEnvelopeItem])>()
    public override func capture(event: Event, scope: Scope, additionalEnvelopeItems: [SentryEnvelopeItem]) -> SentryId {
        captureEventWithScopeInvocations.record((event, scope, additionalEnvelopeItems))
        return event.eventId
    }
    
    var captureMessageInvocations = Invocations<String>()
    public override func capture(message: String) -> SentryId {
        self.captureMessageInvocations.record(message)
        return SentryId()
    }
    
    public var captureMessageWithScopeInvocations = Invocations<(message: String, scope: Scope)>()
    public override func capture(message: String, scope: Scope) -> SentryId {
        captureMessageWithScopeInvocations.record((message, scope))
        return SentryId()
    }
    
    var captureErrorInvocations = Invocations<Error>()
    public override func capture(error: Error) -> SentryId {
        captureErrorInvocations.record(error)
        return SentryId()
    }
    
    public var captureErrorWithScopeInvocations = Invocations<(error: Error, scope: Scope)>()
    public override func capture(error: Error, scope: Scope) -> SentryId {
        captureErrorWithScopeInvocations.record((error, scope))
        return SentryId()
    }
    
    var captureExceptionInvocations = Invocations<NSException>()
    public override func capture(exception: NSException) -> SentryId {
        captureExceptionInvocations.record(exception)
        return SentryId()
    }
    
    public var captureExceptionWithScopeInvocations = Invocations<(exception: NSException, scope: Scope)>()
    public override func capture(exception: NSException, scope: Scope) -> SentryId {
        captureExceptionWithScopeInvocations.record((exception, scope))
        return SentryId()
    }

    public var callSessionBlockWithIncrementSessionErrors = true
    public var captureErrorWithSessionInvocations = Invocations<(error: Error, session: SentrySession?, scope: Scope)>()
    public override func captureError(_ error: Error, with scope: Scope, incrementSessionErrors sessionBlock: @escaping () -> SentrySession) -> SentryId {
        captureErrorWithSessionInvocations.record((error, callSessionBlockWithIncrementSessionErrors ? sessionBlock() : nil, scope))
        return SentryId()
    }
    
    public var captureExceptionWithSessionInvocations = Invocations<(exception: NSException, session: SentrySession?, scope: Scope)>()
    public override func capture(_ exception: NSException, with scope: Scope, incrementSessionErrors sessionBlock: @escaping () -> SentrySession) -> SentryId {
        captureExceptionWithSessionInvocations.record((exception, callSessionBlockWithIncrementSessionErrors ? sessionBlock() : nil, scope))
        return SentryId()
    }
    
    public var captureCrashEventInvocations = Invocations<(event: Event, scope: Scope)>()
    public override func captureCrash(_ event: Event, with scope: Scope) -> SentryId {
        captureCrashEventInvocations.record((event, scope))
        return SentryId()
    }
    
    public var captureCrashEventWithSessionInvocations = Invocations<(event: Event, session: SentrySession, scope: Scope)>()
    public override func captureCrash(_ event: Event, with session: SentrySession, with scope: Scope) -> SentryId {
        captureCrashEventWithSessionInvocations.record((event, session, scope))
        return SentryId()
    }
    
    public var captureUserFeedbackInvocations = Invocations<UserFeedback>()
    public override func capture(userFeedback: UserFeedback) {
        captureUserFeedbackInvocations.record(userFeedback)
    }
    
    public var captureEnvelopeInvocations = Invocations<SentryEnvelope>()
    public override func capture(_ envelope: SentryEnvelope) {
        captureEnvelopeInvocations.record(envelope)
    }
    
    public var storedEnvelopeInvocations = Invocations<SentryEnvelope>()
    public override func store(_ envelope: SentryEnvelope) {
        storedEnvelopeInvocations.record(envelope)
    }
    
    public var recordLostEvents = Invocations<(category: SentryDataCategory, reason: SentryDiscardReason)>()
    public override func recordLostEvent(_ category: SentryDataCategory, reason: SentryDiscardReason) {
        recordLostEvents.record((category, reason))
    }
    
    public var flushInvocations = Invocations<TimeInterval>()
    public override func flush(timeout: TimeInterval) {
        flushInvocations.record(timeout)
    }
}

public class TestFileManager: SentryFileManager {
    var timestampLastInForeground: Date?
    var readTimestampLastInForegroundInvocations: Int = 0
    var storeTimestampLastInForegroundInvocations: Int = 0
    var deleteTimestampLastInForegroundInvocations: Int = 0

    public init(options: Options) throws {
        try super.init(options: options, dispatchQueueWrapper: TestSentryDispatchQueueWrapper())
    }
    
    public var deleteOldEnvelopeItemsInvocations = Invocations<Void>()
    public override func deleteOldEnvelopeItems() {
        deleteOldEnvelopeItemsInvocations.record(Void())
    }

    public override func readTimestampLastInForeground() -> Date? {
        readTimestampLastInForegroundInvocations += 1
        return timestampLastInForeground
    }

    public override func storeTimestampLast(inForeground: Date) {
        storeTimestampLastInForegroundInvocations += 1
        timestampLastInForeground = inForeground
    }

    public override func deleteTimestampLastInForeground() {
        deleteTimestampLastInForegroundInvocations += 1
        timestampLastInForeground = nil
    }
    
    var readAppStateInvocations = Invocations<Void>()
    public override func readAppState() -> SentryAppState? {
        readAppStateInvocations.record(Void())
        return nil
    }

    var appState: SentryAppState?
    public var readPreviousAppStateInvocations = Invocations<Void>()
    public override func readPreviousAppState() -> SentryAppState? {
        readPreviousAppStateInvocations.record(Void())
        return appState
    }
}
