import _SentryPrivate
import Foundation

public class TestClient: SentryClient {
    public override init?(options: Options) {
        super.init(options: options, fileManager: try! TestFileManager(options: options), deleteOldEnvelopeItems: false, transportAdapter: TestTransportAdapter(transports: [TestTransport()], options: options))
    }

    public override init?(options: Options, fileManager: SentryFileManager, deleteOldEnvelopeItems: Bool) {
        super.init(options: options, fileManager: fileManager, deleteOldEnvelopeItems: deleteOldEnvelopeItems, transportAdapter: TestTransportAdapter(transports: [TestTransport()], options: options))
    }
    
    public override init(options: Options, fileManager: SentryFileManager, deleteOldEnvelopeItems: Bool, transportAdapter: SentryTransportAdapter) {
        super.init(options: options, fileManager: fileManager, deleteOldEnvelopeItems: deleteOldEnvelopeItems, transportAdapter: transportAdapter)
    }
    
    // Without this override we get a fatal error: use of unimplemented initializer
    // see https://stackoverflow.com/questions/28187261/ios-swift-fatal-error-use-of-unimplemented-initializer-init
    public override init(options: Options, transportAdapter: SentryTransportAdapter, fileManager: SentryFileManager, deleteOldEnvelopeItems: Bool, threadInspector: SentryThreadInspector, debugImageProvider: SentryDebugImageProvider, random: SentryRandomProtocol, locale: Locale, timezone: TimeZone) {
        super.init(
            options: options,
            transportAdapter: transportAdapter,
            fileManager: fileManager,
            deleteOldEnvelopeItems: false,
            threadInspector: threadInspector,
            debugImageProvider: debugImageProvider,
            random: random,
            locale: locale,
            timezone: timezone
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
    
    public var captureFatalEventInvocations = Invocations<(event: Event, scope: Scope)>()
    public override func captureFatalEvent(_ event: Event, with scope: Scope) -> SentryId {
        captureFatalEventInvocations.record((event, scope))
        return SentryId()
    }
    
    public var captureFatalEventWithSessionInvocations = Invocations<(event: Event, session: SentrySession, scope: Scope)>()
    public override func captureFatalEvent(_ event: Event, with session: SentrySession, with scope: Scope) -> SentryId {
        captureFatalEventWithSessionInvocations.record((event, session, scope))
        return SentryId()
    }
    
    public var saveCrashTransactionInvocations = Invocations<(event: Event, scope: Scope)>()
    public override func saveCrashTransaction(transaction: Transaction, scope: Scope) {
        saveCrashTransactionInvocations.record((transaction, scope))
    }
    
    @available(*, deprecated, message: "-[SentryClient captureUserFeedback:] is deprecated. -[SentryClient captureFeedback:withScope:] is the new way. See captureFeedbackInvocations.")
    public var captureUserFeedbackInvocations = Invocations<UserFeedback>()
    @available(*, deprecated, message: "-[SentryClient captureUserFeedback:] is deprecated. -[SentryClient captureFeedback:withScope:] is the new way. See capture(feedback:scope:).")
    public override func capture(userFeedback: UserFeedback) {
        captureUserFeedbackInvocations.record(userFeedback)
    }
    
    public var captureFeedbackInvocations = Invocations<(SentryFeedback, Scope)>()
    public override func capture(feedback: SentryFeedback, scope: Scope) {
        captureFeedbackInvocations.record((feedback, scope))
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
    
    public var recordLostEventsWithQauntity = Invocations<(category: SentryDataCategory, reason: SentryDiscardReason, quantity: UInt)>()
    public override func recordLostEvent(_ category: SentryDataCategory, reason: SentryDiscardReason, quantity: UInt) {
        recordLostEventsWithQauntity.record((category, reason, quantity))
    }
    
    public var flushInvocations = Invocations<TimeInterval>()
    public override func flush(timeout: TimeInterval) {
        flushInvocations.record(timeout)
    }
}
