import _SentryPrivate
import Foundation
@_spi(Private) import Sentry

public class TestClient: SentryClient {
    public override init?(options: Options) {
        super.init(
            options: options,
            transportAdapter: TestTransportAdapter(transports: [TestTransport()], options: options),
            fileManager: try! TestFileManager(
                options: options,
                dateProvider: TestCurrentDateProvider(),
                dispatchQueueWrapper: TestSentryDispatchQueueWrapper()
            ),
            threadInspector: SentryDefaultThreadInspector(options: options),
            debugImageProvider: SentryDependencyContainer.sharedInstance().debugImageProvider,
            random: SentryDependencyContainer.sharedInstance().random,
            locale: NSLocale.autoupdatingCurrent,
            timezone: NSCalendar.autoupdatingCurrent.timeZone
        )
    }
    
    // Without this override we get a fatal error: use of unimplemented initializer
    // see https://stackoverflow.com/questions/28187261/ios-swift-fatal-error-use-of-unimplemented-initializer-init
    @_spi(Private) public override init(options: Options, transportAdapter: SentryTransportAdapter, fileManager: SentryFileManager, threadInspector: SentryDefaultThreadInspector, debugImageProvider: SentryDebugImageProvider, random: SentryRandomProtocol, locale: Locale, timezone: TimeZone) {
        super.init(
            options: options,
            transportAdapter: transportAdapter,
            fileManager: fileManager,
            threadInspector: threadInspector,
            debugImageProvider: debugImageProvider,
            random: random,
            locale: locale,
            timezone: timezone
        )
    }
    
    @_spi(Private)
    public var captureSessionInvocations = Invocations<SentrySession>()
    @_spi(Private)
    public override func capture(session: SentrySession) {
        captureSessionInvocations.record(session)
    }
    
    public var captureEventInvocations = Invocations<Event>()
    public override func capture(event: Event) -> SentryId {
        captureEventInvocations.record(event)
        return event.eventId
    }
    
    @_spi(Private) public var captureEventWithScopeInvocations = Invocations<(event: Event, scope: Scope, additionalEnvelopeItems: [SentryEnvelopeItem])>()
    @_spi(Private) public override func capture(event: Event, scope: Scope, additionalEnvelopeItems: [SentryEnvelopeItem]) -> SentryId {
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
    @_spi(Private)
    public var captureErrorWithSessionInvocations = Invocations<(error: Error, session: SentrySession?, scope: Scope)>()
    @_spi(Private)
    public override func captureError(_ error: Error, with scope: Scope, incrementSessionErrors sessionBlock: @escaping () -> SentrySession) -> SentryId {
        captureErrorWithSessionInvocations.record((error, callSessionBlockWithIncrementSessionErrors ? sessionBlock() : nil, scope))
        return SentryId()
    }
    
    @_spi(Private)
    public var captureExceptionWithSessionInvocations = Invocations<(exception: NSException, session: SentrySession?, scope: Scope)>()
    @_spi(Private)
    public override func capture(_ exception: NSException, with scope: Scope, incrementSessionErrors sessionBlock: @escaping () -> SentrySession) -> SentryId {
        captureExceptionWithSessionInvocations.record((exception, callSessionBlockWithIncrementSessionErrors ? sessionBlock() : nil, scope))
        return SentryId()
    }
    
    public var captureFatalEventInvocations = Invocations<(event: Event, scope: Scope)>()
    public override func captureFatalEvent(_ event: Event, with scope: Scope) -> SentryId {
        captureFatalEventInvocations.record((event, scope))
        return SentryId()
    }
    
    @_spi(Private)
    public var captureFatalEventWithSessionInvocations = Invocations<(event: Event, session: SentrySession, scope: Scope)>()
    @_spi(Private)
    public override func captureFatalEvent(_ event: Event, with session: SentrySession, with scope: Scope) -> SentryId {
        captureFatalEventWithSessionInvocations.record((event, session, scope))
        return SentryId()
    }
    
    public var saveCrashTransactionInvocations = Invocations<(event: Event, scope: Scope)>()
    public override func saveCrashTransaction(transaction: Transaction, scope: Scope) {
        saveCrashTransactionInvocations.record((transaction, scope))
    }
    
    public var captureFeedbackInvocations = Invocations<(SentryFeedback, Scope)>()
    public override func capture(feedback: SentryFeedback, scope: Scope) {
        captureFeedbackInvocations.record((feedback, scope))
    }
    
    public var captureSerializedFeedbackInvocations = Invocations<(String, Scope)>()
    public override func captureSerializedFeedback(_ serializedFeedback: [AnyHashable: Any], withEventId feedbackEventId: String, attachments: [Attachment], scope: Scope) {
        captureSerializedFeedbackInvocations.record((feedbackEventId, scope))
    }
    
    @_spi(Private) public var captureEnvelopeInvocations = Invocations<SentryEnvelope>()
    @_spi(Private) public override func capture(_ envelope: SentryEnvelope) {
        captureEnvelopeInvocations.record(envelope)
    }
    
    @_spi(Private) public var storedEnvelopeInvocations = Invocations<SentryEnvelope>()
    @_spi(Private) public override func store(_ envelope: SentryEnvelope) {
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
    
    public var captureLogsDataInvocations = Invocations<(data: Data, count: NSNumber)>()
    public override func captureLogsData(_ data: Data, with count: NSNumber) {
        captureLogsDataInvocations.record((data, count))
    }
}
