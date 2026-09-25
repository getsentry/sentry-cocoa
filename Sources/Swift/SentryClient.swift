internal import _SentryPrivate
import Foundation

/// The Sentry client is responsible for capturing events and sending them to Sentry.
@objc public final class SentryClient: NSObject {
    let helper: SentryClientInternal
    
    /// Initializes a `SentryClient`. Pass in a dictionary of options.
    /// - Parameter options: Options dictionary
    /// - Returns: An initialized `SentryClient` or `nil` if an error occurred.
    @objc public init?(options: Options) {
        guard let helper = SentryClientInternal(options: options) else {
            return nil
        }
        self.helper = helper
    }
    
    init(helper: SentryClientInternal) {
        self.helper = helper
    }
    
    /// Indicates whether the client is enabled and will send events to Sentry.
    @objc public var isEnabled: Bool {
        helper.isEnabled
    }
    
    /// The options used to configure this client.
    @objc public var options: Options {
        get {
            // swiftlint:disable force_cast
            return helper.getOptions() as! Options
            // swiftlint:enable force_cast
        }
        set { helper.setOptions(newValue) }
    }
    
    /// Captures a manually created event and sends it to Sentry.
    /// - Parameter event: The event to send to Sentry.
    /// - Returns: The `SentryId` of the event or `SentryId.empty` if the event is not sent.
    @discardableResult @objc(captureEvent:) public func capture(event: Event) -> SentryId {
        helper.capture(event: event)
    }

    /// Captures a manually created event and sends it to Sentry.
    /// - Parameters:
    ///   - event: The event to send to Sentry.
    ///   - scope: The scope containing event metadata.
    /// - Returns: The `SentryId` of the event or `SentryId.empty` if the event is not sent.
    @discardableResult @objc(captureEvent:withScope:) public func capture(event: Event, scope: Scope) -> SentryId {
        helper.capture(event: event, scope: scope)
    }

    /// Captures an error event and sends it to Sentry.
    /// - Parameter error: The error to send to Sentry.
    /// - Returns: The `SentryId` of the event or `SentryId.empty` if the event is not sent.
    @discardableResult @objc(captureError:) public func capture(error: Error) -> SentryId {
        helper.capture(error: error)
    }

    /// Captures an error event and sends it to Sentry.
    /// - Parameters:
    ///   - error: The error to send to Sentry.
    ///   - scope: The scope containing event metadata.
    /// - Returns: The `SentryId` of the event or `SentryId.empty` if the event is not sent.
    @discardableResult @objc(captureError:withScope:) public func capture(error: Error, scope: Scope) -> SentryId {
        helper.capture(error: error, scope: scope)
    }

    /// Captures an exception event and sends it to Sentry.
    /// - Parameter exception: The exception to send to Sentry.
    /// - Returns: The `SentryId` of the event or `SentryId.empty` if the event is not sent.
    @discardableResult @objc(captureException:) public func capture(exception: NSException) -> SentryId {
        helper.capture(exception: exception)
    }

    /// Captures an exception event and sends it to Sentry.
    /// - Parameters:
    ///   - exception: The exception to send to Sentry.
    ///   - scope: The scope containing event metadata.
    /// - Returns: The `SentryId` of the event or `SentryId.empty` if the event is not sent.
    @discardableResult @objc(captureException:withScope:) public func capture(exception: NSException, scope: Scope) -> SentryId {
        helper.capture(exception: exception, scope: scope)
    }

    /// Captures a message event and sends it to Sentry.
    /// - Parameter message: The message to send to Sentry.
    /// - Returns: The `SentryId` of the event or `SentryId.empty` if the event is not sent.
    @discardableResult @objc(captureMessage:) public func capture(message: String) -> SentryId {
        helper.capture(message: message)
    }

    /// Captures a message event and sends it to Sentry.
    /// - Parameters:
    ///   - message: The message to send to Sentry.
    ///   - scope: The scope containing event metadata.
    /// - Returns: The `SentryId` of the event or `SentryId.empty` if the event is not sent.
    @discardableResult @objc(captureMessage:withScope:) public func capture(message: String, scope: Scope) -> SentryId {
        helper.capture(message: message, scope: scope)
    }

    /// Captures a new-style user feedback and sends it to Sentry.
    /// - Parameters:
    ///   - feedback: The user feedback to send to Sentry.
    ///   - scope: The current scope from which to gather contextual information.
    @objc(captureFeedback:withScope:) public func capture(feedback: SentryFeedback, scope: Scope) {
        helper.captureSerializedFeedback(
          feedback.serialize(),
          withEventId: feedback.eventId.sentryIdString,
          attachments: feedback.attachmentsForEnvelope(),
          scope: scope)
    }

    /// Captures a log entry and sends it to Sentry.
    /// - Parameters:
    ///   - log: The log entry to send to Sentry.
    ///   - scope: The scope containing event metadata.
    @objc(captureLog:withScope:) public func capture(log: SentryLog, scope: Scope) {
        helper._swiftCaptureLog(log, with: scope)
    }

    /// Waits synchronously for the SDK to flush out all queued and cached items for up to the specified timeout in seconds.
    /// If there is no internet connection, the function returns immediately. The SDK doesn't dispose the client or the hub.
    /// - Parameter timeout: The time to wait for the SDK to complete the flush.
    @objc(flush:) public func flush(timeout: TimeInterval) {
        helper.flush(timeout: timeout)
    }

    /// Disables the client and calls flush with `SentryOptions.shutdownTimeInterval`.
    @objc public func close() {
        helper.close()
    }

}

// swiftlint:disable missing_docs file_length type_body_length function_body_length function_parameter_count cyclomatic_complexity force_cast
@_spi(Private) @objc public protocol SentrySessionDelegate: NSObjectProtocol {
    func incrementSessionErrors() -> SentrySession?
}

@_spi(Private) @objc public protocol SentryClientAttachmentProcessor: NSObjectProtocol {
    @objc(processAttachments:forEvent:)
    func processAttachments(_ attachments: [Attachment], for event: Event) -> [Attachment]
}

private let dropSessionLogMessage = "Session has no release name. Won't send it."

@_spi(Private) @objc(SentryClientInternal) @objcMembers
open class SentryClientInternal: NSObject {
    public private(set) var isEnabled = true
    open var options: Options
    public var attachmentProcessors = NSMutableArray()
    public var threadInspector: SentryDefaultThreadInspector
    public var fileManager: SentryFileManager
    public weak var sessionDelegate: SentrySessionDelegate?
    @objc private dynamic var transportAdapter: SentryTransportAdapter
    @objc private dynamic var debugImageProvider: SentryDebugImageProvider
    @objc private dynamic var random: SentryRandomProtocol
    @objc private dynamic var locale: NSLocale
    @objc private dynamic var timezone: NSTimeZone
    @objc private dynamic var logScopeApplier: SentryLogScopeApplier
    dynamic var telemetryProcessor: SentryObjCTelemetryProcessor
    @objc private dynamic var eventContextEnricher: SentryEventContextEnricher
    @objc private dynamic var dispatchQueueWrapper: SentryDispatchQueueWrapper
    @objc private dynamic var currentScopeStorage: SentryCurrentScopeStorage

    @objc(initWithOptions:)
    public convenience init?(options: NSObject) {
        let options = options as! Options
        let dependencies = SentryDependencyContainer.sharedInstance()
        let fileManager: SentryFileManager
        do {
            fileManager = try SentryFileManager(
                options: options,
                dateProvider: dependencies.dateProvider,
                dispatchQueueWrapper: dependencies.dispatchQueueWrapper
            )
        } catch {
            SentrySDKLog.fatal("Failed to initialize file system: \(error.localizedDescription)")
            return nil
        }
        let transports = sentry_clientCreateTransports(
            options,
            dependencies.dateProvider,
            fileManager,
            dependencies.rateLimits,
            dependencies.reachability
        )
        let transportAdapter = SentryTransportAdapter(transports: transports as! [Transport], options: options)
        let threadInspector = SentryDefaultThreadInspector(options: options)
        self.init(
            options: options,
            dateProvider: dependencies.dateProvider,
            transportAdapter: transportAdapter,
            fileManager: fileManager,
            threadInspector: threadInspector,
            debugImageProvider: dependencies.debugImageProvider,
            random: dependencies.random,
            locale: .autoupdatingCurrent,
            timezone: Calendar.autoupdatingCurrent.timeZone,
            eventContextEnricher: dependencies.eventContextEnricher,
            binaryImageCache: dependencies.binaryImageCache,
            dispatchQueueWrapper: dependencies.dispatchQueueWrapper,
            currentScopeStorage: dependencies.currentScopeStorage
        )
    }

    public convenience init(
        options: Options,
        dateProvider: SentryCurrentDateProvider,
        transportAdapter: SentryTransportAdapter,
        fileManager: SentryFileManager,
        threadInspector: SentryDefaultThreadInspector,
        debugImageProvider: SentryDebugImageProvider,
        random: SentryRandomProtocol,
        locale: Locale,
        timezone: TimeZone,
        eventContextEnricher: SentryEventContextEnricher,
        binaryImageCache: SentryBinaryImageCache,
        dispatchQueueWrapper: SentryDispatchQueueWrapper
    ) {
        self.init(
            options: options,
            dateProvider: dateProvider,
            transportAdapter: transportAdapter,
            fileManager: fileManager,
            threadInspector: threadInspector,
            debugImageProvider: debugImageProvider,
            random: random,
            locale: locale,
            timezone: timezone,
            eventContextEnricher: eventContextEnricher,
            binaryImageCache: binaryImageCache,
            dispatchQueueWrapper: dispatchQueueWrapper,
            currentScopeStorage: SentryDependencyContainer.sharedInstance().currentScopeStorage
        )
    }

    public init(
        options: Options,
        dateProvider: SentryCurrentDateProvider,
        transportAdapter: SentryTransportAdapter,
        fileManager: SentryFileManager,
        threadInspector: SentryDefaultThreadInspector,
        debugImageProvider: SentryDebugImageProvider,
        random: SentryRandomProtocol,
        locale: Locale,
        timezone: TimeZone,
        eventContextEnricher: SentryEventContextEnricher,
        binaryImageCache: SentryBinaryImageCache,
        dispatchQueueWrapper: SentryDispatchQueueWrapper,
        currentScopeStorage: SentryCurrentScopeStorage
    ) {
        self.options = options
        self.transportAdapter = transportAdapter
        self.fileManager = fileManager
        self.threadInspector = threadInspector
        self.random = random
        self.debugImageProvider = debugImageProvider
        self.locale = locale as NSLocale
        self.timezone = timezone as NSTimeZone
        self.eventContextEnricher = eventContextEnricher
        self.dispatchQueueWrapper = dispatchQueueWrapper
        self.currentScopeStorage = currentScopeStorage
        self.telemetryProcessor = SentryTelemetryProcessorFactory.getProcessor(
            transport: SentryDefaultTelemetryProcessorTransport(transportAdapter: transportAdapter)
                as! SentryTelemetryProcessorTransport,
            dependencies: SentryDependencyContainer.sharedInstance()
        )
        #if SDK_V10
            let shouldAddDefaultUserId = options.dataCollection.userInfo
        #else
            let shouldAddDefaultUserId = options.sendDefaultPii
        #endif
        self.logScopeApplier = SentryDefaultLogScopeApplier(
            environment: options.environment,
            releaseName: options.releaseName,
            cacheDirectoryPath: options.cacheDirectoryPath,
            shouldAddDefaultUserId: shouldAddDefaultUserId
        )
        super.init()
        binaryImageCache.start(options.debug)
        // The first installation ID lookup performs file IO. Cache it off the main thread.
        SentryInstallation.cacheIDAsync(withCacheDirectoryPath: options.cacheDirectoryPath)
        fileManager.deleteOldEnvelopeItems()
    }

    @objc(setOptionsInternal:)
    open func setOptions(_ optionsInternal: Options) { options = optionsInternal }
    open func getOptions() -> NSObject { options }

    @discardableResult @objc(captureMessage:)
    open func capture(message: String) -> SentryId { capture(message: message, scope: Scope()) }
    @discardableResult @objc(captureMessage:withScope:)
    open func capture(message: String, scope: Scope) -> SentryId { capture(message: message, scope: scope, hint: nil) }
    @discardableResult @objc(captureMessage:withScope:attachAllThreads:)
    open func capture(message: String, scope: Scope, attachAllThreads: NSNumber?) -> SentryId {
        let event = Event(level: .info)
        event.message = SentryMessage(formatted: message)
        event.attachAllThreadsOverride = attachAllThreads
        return sendEvent(event, with: scope, alwaysAttachStacktrace: false, hint: Hint())
    }
    @discardableResult @objc(captureException:)
    open func capture(exception: NSException) -> SentryId { capture(exception: exception, scope: Scope()) }
    @discardableResult @objc(captureException:withScope:)
    open func capture(exception: NSException, scope: Scope) -> SentryId {
        capture(exception: exception, scope: scope, hint: nil)
    }
    @discardableResult @objc(captureException:withScope:attachAllThreads:)
    open func capture(exception: NSException, scope: Scope, attachAllThreads: NSNumber?) -> SentryId {
        let event = buildExceptionEvent(exception)
        event.attachAllThreadsOverride = attachAllThreads
        return captureEventIncrementingSessionErrorCount(event, with: scope, hint: Hint(exception: exception))
    }
    func buildExceptionEvent(_ exception: NSException) -> Event {
        let event = Event(level: .error)
        event.exceptions = [Exception(value: exception.reason, type: exception.name.rawValue)]
        setUserInfo(exception.userInfo, with: event)
        return event
    }
    @discardableResult @objc(captureError:)
    open func capture(error: Error) -> SentryId { capture(error: error, scope: Scope()) }
    @discardableResult @objc(captureError:withScope:)
    open func capture(error: Error, scope: Scope) -> SentryId { capture(error: error, scope: scope, hint: nil) }
    @discardableResult @objc(captureError:withScope:attachAllThreads:)
    open func capture(error: Error, scope: Scope, attachAllThreads: NSNumber?) -> SentryId {
        let event = buildErrorEvent(error as NSError)
        event.attachAllThreadsOverride = attachAllThreads
        return captureEventIncrementingSessionErrorCount(event, with: scope, hint: Hint(error: error))
    }
    func buildErrorEvent(_ error: NSError) -> Event {
        let event = Event(error: error)
        // Flatten underlying errors oldest to newest, keeping the root userInfo for context.
        var errors = [error]
        var underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError
        if underlyingError == nil, let invalid = error.userInfo[NSUnderlyingErrorKey] {
            SentrySDKLog.warning(
                "Invalid value for NSUnderlyingErrorKey in user info. Data at key: \(invalid). Class type: \(type(of: invalid))."
            )
        }
        while let nextError = underlyingError {
            errors.append(nextError)
            underlyingError = nextError.userInfo[NSUnderlyingErrorKey] as? NSError
            if underlyingError == nil, let invalid = nextError.userInfo[NSUnderlyingErrorKey] {
                SentrySDKLog.warning(
                    "Invalid value for NSUnderlyingErrorKey in user info. Data at key: \(invalid). Class type: \(type(of: invalid))."
                )
            }
        }
        event.exceptions = errors.reversed().map { [self] in exception(for: $0) }
        setUserInfo(sentry_sanitize_dictionary(error.userInfo), with: event)
        return event
    }
    @objc(exceptionForError:)
    func exception(for error: NSError) -> Exception {
        let customExceptionValue = (error.userInfo as NSDictionary).value(forKey: NSDebugDescriptionErrorKey)
        var swiftErrorDescription: String?
        if NSStringFromClass(type(of: error)).contains("SwiftNativeNSError") {
            swiftErrorDescription = SwiftDescriptor.getSwiftErrorDescription(error)
        }
        let exceptionValue: String
        if let customExceptionValue {
            exceptionValue = String(
                format: "%@ (Code: %ld)",
                String(describing: customExceptionValue) as NSString,
                error.code
            )
        } else if let swiftErrorDescription {
            exceptionValue = "\(swiftErrorDescription) (Code: \(error.code))"
        } else {
            exceptionValue = "Code: \(error.code)"
        }
        let exception = Exception(value: exceptionValue, type: error.domain)
        let mechanism = Mechanism(type: "NSError")
        let meta = MechanismContext()
        meta.error = SentryNSError(domain: error.domain, code: error.code)
        mechanism.meta = meta
        mechanism.desc = error.description
        mechanism.data = sentry_sanitize_dictionary(error.userInfo) as? [String: Any]
        exception.mechanism = mechanism
        return exception
    }

    // Populate attachments before beforeSendWithHint. Its resulting list is authoritative.
    func populateHintAttachments(_ hint: Hint, scope: Scope, isFatalEvent: Bool) {
        var allAttachments = scope.attachments
        if !isFatalEvent, let currentScope = currentScopeStorage.scope() {
            for attachment in currentScope.attachments where !allAttachments.contains(where: { $0 === attachment }) {
                allAttachments.append(attachment)
            }
        }
        allAttachments.append(contentsOf: hint.attachments)
        hint.attachments = allAttachments
    }
    @discardableResult @objc(captureFatalEvent:withScope:)
    open func captureFatalEvent(_ event: Event, with scope: Scope) -> SentryId {
        sendEvent(event, with: scope, alwaysAttachStacktrace: false, isFatalEvent: true, hint: Hint())
    }
    @discardableResult @objc(captureFatalEvent:withSession:withScope:)
    open func captureFatalEvent(_ event: Event, with session: SentrySession, with scope: Scope) -> SentryId {
        let hint = Hint()
        populateHintAttachments(hint, scope: scope, isFatalEvent: true)
        hint.attachments = processAttachments(for: event, attachments: hint.attachments)
        let preparedEvent = prepareEvent(
            event,
            with: scope,
            alwaysAttachStacktrace: false,
            isFatalEvent: true,
            hint: hint
        )
        return sendEvent(preparedEvent, with: session, with: scope, hint: hint)
    }
    @objc(saveCrashTransaction:withScope:)
    open func saveCrashTransaction(transaction: Transaction, scope: Scope) {
        guard
            let preparedEvent = prepareEvent(
                transaction,
                with: scope,
                alwaysAttachStacktrace: false,
                isFatalEvent: false
            )
        else { return }
        let traceContext = getTraceState(with: transaction, with: scope, currentScope: nil)
        transportAdapter.store(preparedEvent, traceContext: traceContext)
    }
    @discardableResult @objc(captureEvent:)
    open func capture(event: Event) -> SentryId { capture(event: event, scope: Scope()) }
    @discardableResult @objc(captureEvent:withScope:)
    open func capture(event: Event, scope: Scope) -> SentryId { capture(event: event, scope: scope, hint: nil) }
    @discardableResult @objc(captureEvent:withScope:additionalEnvelopeItems:)
    open func capture(event: Event, scope: Scope, additionalEnvelopeItems: [SentryEnvelopeItem]) -> SentryId {
        sendEvent(
            event,
            with: scope,
            alwaysAttachStacktrace: false,
            isFatalEvent: false,
            additionalEnvelopeItems: additionalEnvelopeItems,
            hint: Hint()
        )
    }
    @discardableResult @objc(captureEvent:withScope:hint:)
    open func capture(event: Event, scope: Scope, hint: Hint?) -> SentryId {
        sendEvent(event, with: scope, alwaysAttachStacktrace: false, hint: hint ?? Hint())
    }
    @discardableResult @objc(captureError:withScope:hint:)
    open func capture(error: Error, scope: Scope, hint: Hint?) -> SentryId {
        let resolvedHint = hint ?? Hint()
        let event = buildErrorEvent(error as NSError)
        if resolvedHint.originalError == nil { resolvedHint.originalError = error as NSError }
        return captureEventIncrementingSessionErrorCount(event, with: scope, hint: resolvedHint)
    }
    @discardableResult @objc(captureException:withScope:hint:)
    open func capture(exception: NSException, scope: Scope, hint: Hint?) -> SentryId {
        let resolvedHint = hint ?? Hint()
        let event = buildExceptionEvent(exception)
        if resolvedHint.originalException == nil { resolvedHint.originalException = exception }
        return captureEventIncrementingSessionErrorCount(event, with: scope, hint: resolvedHint)
    }
    @discardableResult @objc(captureMessage:withScope:hint:)
    open func capture(message: String, scope: Scope, hint: Hint?) -> SentryId {
        let resolvedHint = hint ?? Hint()
        let event = Event(level: .info)
        event.message = SentryMessage(formatted: message)
        return sendEvent(event, with: scope, alwaysAttachStacktrace: false, hint: resolvedHint)
    }
    @discardableResult @objc(captureEventIncrementingSessionErrorCount:withScope:)
    open func captureEventIncrementingSessionErrorCount(_ event: Event, with scope: Scope) -> SentryId {
        captureEventIncrementingSessionErrorCount(event, with: scope, hint: Hint())
    }
    @discardableResult @objc(captureEventIncrementingSessionErrorCount:withScope:hint:)
    open func captureEventIncrementingSessionErrorCount(_ event: Event, with scope: Scope, hint: Hint) -> SentryId {
        populateHintAttachments(hint, scope: scope, isFatalEvent: false)
        hint.attachments = processAttachments(for: event, attachments: hint.attachments)
        if let preparedEvent = prepareEvent(
            event,
            with: scope,
            alwaysAttachStacktrace: true,
            isFatalEvent: false,
            hint: hint
        ) {
            let delegate = sessionDelegate
            let session = delegate?.incrementSessionErrors()
            return sendEvent(preparedEvent, with: session, with: scope, hint: hint)
        }
        return .empty
    }

    @objc(sendEvent:withScope:alwaysAttachStacktrace:)
    func sendEvent(_ event: Event, with scope: Scope, alwaysAttachStacktrace: Bool) -> SentryId {
        sendEvent(
            event,
            with: scope,
            alwaysAttachStacktrace: alwaysAttachStacktrace,
            isFatalEvent: false,
            additionalEnvelopeItems: [],
            hint: Hint()
        )
    }
    @objc(sendEvent:withScope:alwaysAttachStacktrace:hint:)
    func sendEvent(_ event: Event, with scope: Scope, alwaysAttachStacktrace: Bool, hint: Hint) -> SentryId {
        sendEvent(
            event,
            with: scope,
            alwaysAttachStacktrace: alwaysAttachStacktrace,
            isFatalEvent: false,
            additionalEnvelopeItems: [],
            hint: hint
        )
    }
    @objc(getTraceStateWithEvent:withScope:currentScope:)
    func getTraceState(with event: Event, with scope: Scope, currentScope: Scope?) -> TraceContext? {
        let currentScopeSpan = currentScope?.span
        let span: Span?
        if let transaction = event as? Transaction {
            span = transaction.trace
        } else {
            span = currentScopeSpan ?? scope.span
        }
        if let tracer = SentryTracer.getTracer(span) {
            return TraceContext(tracer: tracer, scope: scope, options: options)
        }
        if event.error != nil || !(event.exceptions?.isEmpty ?? true) {
            let traceId = currentScopeSpan?.traceId ?? scope.propagationContextTraceId
            return TraceContext(trace: traceId, options: options, replayId: scope.replayId)
        }
        return nil
    }
    @objc(sendEvent:withScope:alwaysAttachStacktrace:isFatalEvent:)
    func sendEvent(_ event: Event, with scope: Scope, alwaysAttachStacktrace: Bool, isFatalEvent: Bool) -> SentryId {
        sendEvent(
            event,
            with: scope,
            alwaysAttachStacktrace: alwaysAttachStacktrace,
            isFatalEvent: isFatalEvent,
            additionalEnvelopeItems: [],
            hint: Hint()
        )
    }
    @objc(sendEvent:withScope:alwaysAttachStacktrace:isFatalEvent:hint:)
    func sendEvent(_ event: Event, with scope: Scope, alwaysAttachStacktrace: Bool, isFatalEvent: Bool, hint: Hint)
        -> SentryId {
        sendEvent(
            event,
            with: scope,
            alwaysAttachStacktrace: alwaysAttachStacktrace,
            isFatalEvent: isFatalEvent,
            additionalEnvelopeItems: [],
            hint: hint
        )
    }
    @objc(sendEvent:withScope:alwaysAttachStacktrace:isFatalEvent:additionalEnvelopeItems:)
    func sendEvent(
        _ event: Event,
        with scope: Scope,
        alwaysAttachStacktrace: Bool,
        isFatalEvent: Bool,
        additionalEnvelopeItems: [SentryEnvelopeItem]
    ) -> SentryId {
        sendEvent(
            event,
            with: scope,
            alwaysAttachStacktrace: alwaysAttachStacktrace,
            isFatalEvent: isFatalEvent,
            additionalEnvelopeItems: additionalEnvelopeItems,
            hint: Hint()
        )
    }
    @objc(sendEvent:withScope:alwaysAttachStacktrace:isFatalEvent:additionalEnvelopeItems:hint:)
    func sendEvent(
        _ event: Event,
        with scope: Scope,
        alwaysAttachStacktrace: Bool,
        isFatalEvent: Bool,
        additionalEnvelopeItems: [SentryEnvelopeItem],
        hint: Hint
    ) -> SentryId {
        populateHintAttachments(hint, scope: scope, isFatalEvent: isFatalEvent)
        hint.attachments = processAttachments(for: event, attachments: hint.attachments)
        guard
            let preparedEvent = prepareEvent(
                event,
                with: scope,
                alwaysAttachStacktrace: alwaysAttachStacktrace,
                isFatalEvent: isFatalEvent,
                hint: hint
            )
        else { return .empty }
        let traceContext = getTraceState(
            with: event,
            with: scope,
            currentScope: isFatalEvent ? nil : currentScopeStorage.scope()
        )
        transportAdapter.send(
            event: preparedEvent,
            traceContext: traceContext,
            attachments: hint.attachments,
            additionalEnvelopeItems: additionalEnvelopeItems
        )
        return preparedEvent.eventId
    }
    @objc(sendEvent:withSession:withScope:)
    func sendEvent(_ event: Event?, with session: SentrySession?, with scope: Scope) -> SentryId {
        let hint = Hint()
        populateHintAttachments(hint, scope: scope, isFatalEvent: event?.isFatalEvent ?? false)
        if let event { hint.attachments = processAttachments(for: event, attachments: hint.attachments) }
        return sendEvent(event, with: session, with: scope, hint: hint)
    }
    @objc(sendEvent:withSession:withScope:hint:)
    func sendEvent(_ event: Event?, with session: SentrySession?, with scope: Scope, hint: Hint) -> SentryId {
        guard let event else { return .empty }
        let attachments = hint.attachments
        if event.isFatalEvent, let replay = event.context?["replay"] as? NSDictionary {
            scope.replayId = replay["replay_id"] as? String
        }
        let traceContext = getTraceState(
            with: event,
            with: scope,
            currentScope: event.isFatalEvent ? nil : currentScopeStorage.scope()
        )
        guard let session else {
            transportAdapter.send(event: event, traceContext: traceContext, attachments: attachments)
            return event.eventId
        }
        if session.releaseName?.isEmpty ?? true {
            SentrySDKLog.debug(dropSessionLogMessage)
            transportAdapter.send(event: event, traceContext: traceContext, attachments: attachments)
            return event.eventId
        }
        transportAdapter.send(event, with: session, traceContext: traceContext, attachments: attachments)
        return event.eventId
    }
    @objc(captureSession:)
    open func capture(session: SentrySession) {
        if session.releaseName?.isEmpty ?? true { SentrySDKLog.debug(dropSessionLogMessage); return }
        captureEnvelope(SentryEnvelope(header: .empty(), singleItem: SentryEnvelopeItem(session: session)))
    }
    @objc(captureReplayEvent:replayRecording:video:withScope:)
    open func capture(
        _ replayEvent: SentryReplayEvent,
        replayRecording: SentryReplayRecording,
        video: URL,
        with scope: Scope
    ) {
        guard let preparedEvent = prepareEvent(replayEvent, with: scope, alwaysAttachStacktrace: false) else {
            SentrySDKLog.debug("The replay event was filtered out in prepare event. The replay was discarded.")
            return
        }
        guard let replayEvent = preparedEvent as? SentryReplayEvent else {
            SentrySDKLog.error(
                "The event preprocessor didn't update the replay event in place. The replay was discarded."
            )
            return
        }
        guard let item = SentryEnvelopeItem(replayEvent: replayEvent, replayRecording: replayRecording, video: video)
        else {
            SentrySDKLog.error(
                "The Session Replay segment will not be sent to Sentry because an Envelope Item could not be created."
            )
            recordLostEvent(.replay, reason: .insufficientData, quantity: 1)
            return
        }
        let header = SentryEnvelopeHeader(id: replayEvent.eventId, sdkInfo: replayEvent.sdk)
        captureEnvelope(SentryEnvelope(header: header, items: [item]))
    }
    open func captureEnvelope(_ envelope: SentryEnvelope) {
        if isDisabled { logDisabledMessage(); return }
        transportAdapter.send(envelope: envelope)
    }
    @objc(captureFeedback:withScope:)
    open func capture(feedback: SentryFeedback, scope: Scope) {
        let currentScope = currentScopeStorage.scope()
        captureSerializedFeedback(
            feedback.serialize(),
            withEventId: feedback.eventId.sentryIdString,
            attachments: feedback.attachmentsForEnvelope(),
            scope: scope,
            currentScope: currentScope
        )
    }
    @objc(captureSerializedFeedback:withEventId:attachments:scope:currentScope:)
    func captureSerializedFeedback(
        _ serializedFeedback: [AnyHashable: Any],
        withEventId feedbackEventId: String,
        attachments feedbackAttachments: [Attachment],
        scope: Scope,
        currentScope: Scope?
    ) {
        if isDisabled { logDisabledMessage(); return }
        let event = Event()
        event.eventId = SentryId(uuidString: feedbackEventId)
        event.type = SentryEnvelopeItemTypes.feedback
        let replayId: Any? = serializedFeedback["replay_id"] ?? (currentScope?.replayId ?? scope.replayId) as Any?
        var feedbackContext = serializedFeedback
        feedbackContext["replay_id"] = replayId
        var context: [String: [String: Any]] = ["feedback": feedbackContext as! [String: Any]]
        if let replayId { context["replay"] = ["replay_id": replayId] }
        event.context = context
        guard
            let preparedEvent = prepareEvent(
                event,
                with: scope,
                alwaysAttachStacktrace: false,
                isFatalEvent: false,
                currentScope: currentScope
            )
        else { return }
        let traceContext = getTraceState(with: preparedEvent, with: scope, currentScope: currentScope)
        var allAttachments = scope.attachments
        for attachment in currentScope?.attachments ?? [] where !allAttachments.contains(where: { $0 === attachment }) {
            allAttachments.append(attachment)
        }
        let attachments = processAttachments(for: preparedEvent, attachments: allAttachments) + feedbackAttachments
        transportAdapter.send(
            event: preparedEvent,
            traceContext: traceContext,
            attachments: attachments,
            additionalEnvelopeItems: []
        )
    }
    @objc(captureSerializedFeedback:withEventId:attachments:scope:)
    open func captureSerializedFeedback(
        _ serializedFeedback: [AnyHashable: Any],
        withEventId feedbackEventId: String,
        attachments: [Attachment],
        scope: Scope
    ) {
        let currentScope = currentScopeStorage.scope()
        captureSerializedFeedback(
            serializedFeedback,
            withEventId: feedbackEventId,
            attachments: attachments,
            scope: scope,
            currentScope: currentScope
        )
    }
    /// Used by hybrid SDKs to synchronously store an envelope on disk.
    @objc(storeEnvelope:)
    open func store(_ envelope: SentryEnvelope) { fileManager.store(envelope) }
    open func recordLostEvent(_ category: SentryDataCategory, reason: SentryDiscardReason) {
        transportAdapter.recordLostEvent(category, reason: reason)
    }
    open func recordLostEvent(_ category: SentryDataCategory, reason: SentryDiscardReason, quantity: UInt) {
        transportAdapter.recordLostEvent(category, reason: reason, quantity: quantity)
    }

    @objc(prepareEvent:withScope:alwaysAttachStacktrace:)
    func prepareEvent(_ event: Event?, with scope: Scope, alwaysAttachStacktrace: Bool) -> Event? {
        prepareEvent(event, with: scope, alwaysAttachStacktrace: alwaysAttachStacktrace, isFatalEvent: false)
    }
    @objc(flush:)
    open func flush(timeout: TimeInterval) {
        let duration = telemetryProcessor.forwardTelemetryData()
        // Include forwarding time in the overall timeout, still flushing if it is exhausted.
        transportAdapter.flush(fmax(0, timeout - duration))
    }
    open func close() {
        isEnabled = false
        flush(timeout: options.shutdownTimeInterval)
        SentrySDKLog.debug("Closed the Client.")
    }
    @objc(prepareEvent:withScope:alwaysAttachStacktrace:isFatalEvent:)
    func prepareEvent(_ event: Event?, with scope: Scope, alwaysAttachStacktrace: Bool, isFatalEvent: Bool) -> Event? {
        prepareEvent(
            event,
            with: scope,
            alwaysAttachStacktrace: alwaysAttachStacktrace,
            isFatalEvent: isFatalEvent,
            hint: Hint()
        )
    }
    @objc(prepareEvent:withScope:alwaysAttachStacktrace:isFatalEvent:hint:)
    func prepareEvent(_ event: Event?, with scope: Scope, alwaysAttachStacktrace: Bool, isFatalEvent: Bool, hint: Hint)
        -> Event? {
        let currentScope = currentScopeStorage.scope()
        return prepareEvent(
            event,
            with: scope,
            alwaysAttachStacktrace: alwaysAttachStacktrace,
            isFatalEvent: isFatalEvent,
            currentScope: currentScope,
            hint: hint
        )
    }
    @objc(prepareEvent:withScope:alwaysAttachStacktrace:isFatalEvent:currentScope:)
    func prepareEvent(
        _ event: Event?,
        with scope: Scope,
        alwaysAttachStacktrace: Bool,
        isFatalEvent: Bool,
        currentScope: Scope?
    ) -> Event? {
        prepareEvent(
            event,
            with: scope,
            alwaysAttachStacktrace: alwaysAttachStacktrace,
            isFatalEvent: isFatalEvent,
            currentScope: currentScope,
            hint: Hint()
        )
    }
    @objc(prepareEvent:withScope:alwaysAttachStacktrace:isFatalEvent:currentScope:hint:)
    func prepareEvent(
        _ originalEvent: Event?,
        with scope: Scope,
        alwaysAttachStacktrace: Bool,
        isFatalEvent: Bool,
        currentScope: Scope?,
        hint: Hint
    ) -> Event? {
        assert(originalEvent != nil)
        guard var event = originalEvent else { return nil }
        if isDisabled { logDisabledMessage(); return nil }
        let eventIsNotATransaction = event.type != SentryEnvelopeItemTypes.transaction
        let eventIsNotReplay = event.type != SentryEnvelopeItemTypes.replayVideo
        let eventIsNotUserFeedback = event.type != SentryEnvelopeItemTypes.feedback
        if eventIsNotATransaction && eventIsNotReplay && eventIsNotUserFeedback && isSampled(options.sampleRate) {
            SentrySDKLog.debug("Event got sampled, will not send the event")
            recordLostEvent(.error, reason: .sampleRate)
            return nil
        }
        if let info = Bundle.main.infoDictionary, event.dist == nil { event.dist = info["CFBundleVersion"] as? String }
        if event.releaseName == nil, let release = options.releaseName { event.releaseName = release }
        if let dist = options.dist { event.dist = dist }
        setSdk(event)
        // Transactions, replay and feedback have no attached current threads or debug images.
        if eventIsNotATransaction && eventIsNotReplay && eventIsNotUserFeedback {
            var shouldAttachStacktrace =
                alwaysAttachStacktrace || options.attachStacktrace || !(event.exceptions?.isEmpty ?? true)
            #if os(iOS) || os(macOS) || os(visionOS)
                // MetricKit diagnostics describe past events. Current threads and images cannot fill
                // missing diagnostic data, including when the call stack tree could not be decoded.
                shouldAttachStacktrace = shouldAttachStacktrace && !event.isMetricKitEvent()
            #endif
            let threadsNotAttached = event.threads?.isEmpty ?? true
            if !isFatalEvent && shouldAttachStacktrace && threadsNotAttached {
                let attachAll = event.attachAllThreadsOverride?.boolValue ?? options.attachAllThreads
                event.threads =
                    attachAll ? threadInspector.getCurrentThreadsWithStackTrace() : threadInspector.getCurrentThreads()
            }
            let debugMetaNotAttached = event.debugMeta?.isEmpty ?? true
            if !isFatalEvent && shouldAttachStacktrace && debugMetaNotAttached, let threads = event.threads {
                event.debugMeta = debugImageProvider.getDebugImagesFromCacheForThreads(threads: threads)
            }
        }
        #if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
            if !isFatalEvent && eventIsNotReplay {
                event.context =
                    eventContextEnricher.enrichWithAppState(event.context ?? [:]) as? [String: [String: Any]]
            }
        #endif
        // Fatal events describe a previous run, so never overlay current scopes.
        if !isFatalEvent {
            guard let scopedEvent = scope.applyTo(event: event, maxBreadcrumbs: options.maxBreadcrumbs) else {
                return nil
            }
            event = scopedEvent
        }
        if !isFatalEvent { currentScope?.overlay(on: event, maxBreadcrumb: options.maxBreadcrumbs) }
        if !eventIsNotReplay { event.breadcrumbs = nil }
        if isWatchdogTermination(event, isFatalEvent: isFatalEvent) {
            removeExtraDeviceContext(from: event)
        } else if !isFatalEvent {
            applyExtraDeviceContext(to: event)
            applyCultureContext(to: event)
            #if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
                applyCurrentViewNamesToEventContext(event, with: scope)
            #endif
        }
        if event.environment == nil { event.environment = options.environment }
        setUserIdIfNoUserSet(event)
        let eventIsATransaction = event.type == SentryEnvelopeItemTypes.transaction
        let eventIsATransactionClass = eventIsATransaction && event is Transaction
        var currentSpanCount = eventIsATransactionClass ? UInt((event as? Transaction)?.spans.count ?? 0) : 0
        if eventIsATransaction && options.beforeSendSpan != nil {
            let transaction = event as! Transaction
            var processedSpans: [Span] = []
            for span in transaction.spans {
                if let processedSpan = options.beforeSendSpan?(span) { processedSpans.append(processedSpan) }
            }
            transaction.spans = processedSpans
            if eventIsATransactionClass {
                recordPartiallyDroppedSpans(transaction, with: .beforeSend, withCurrentSpanCount: &currentSpanCount)
            }
        }
        var processedEvent: Event? = event
        #if SDK_V10
            if eventIsATransactionClass {
                if let callback = options.beforeSendTransaction { processedEvent = callback(event as! Transaction) }
                if processedEvent == nil {
                    recordLost(false, reason: .beforeSend)
                    recordLostSpan(with: .beforeSend, quantity: currentSpanCount &+ 1)
                } else if let transaction = processedEvent as? Transaction {
                    recordPartiallyDroppedSpans(transaction, with: .beforeSend, withCurrentSpanCount: &currentSpanCount)
                }
            } else if eventIsNotUserFeedback && !eventIsATransaction {
                if let callback = options.beforeSendWithHint {
                    processedEvent = callback(event, hint)
                } else if let callback = options.beforeSend {
                    processedEvent = callback(event)
                }
                if processedEvent == nil { recordLost(true, reason: .beforeSend) }
            }
        #else
            if eventIsNotUserFeedback {
                if let callback = options.beforeSendWithHint {
                    processedEvent = callback(event, hint)
                } else if let callback = options.beforeSend {
                    processedEvent = callback(event)
                }
                if processedEvent == nil {
                    recordLost(eventIsNotATransaction, reason: .beforeSend)
                    if eventIsATransaction { recordLostSpan(with: .beforeSend, quantity: currentSpanCount &+ 1) }
                } else if let transaction = processedEvent as? Transaction {
                    recordPartiallyDroppedSpans(transaction, with: .beforeSend, withCurrentSpanCount: &currentSpanCount)
                }
            }
        #endif
        if let nextEvent = processedEvent {
            // Dropped events must not trigger processors such as replay capture.
            processedEvent = callEventProcessors(nextEvent)
            if processedEvent == nil {
                recordLost(eventIsNotATransaction, reason: .eventProcessor)
                if eventIsATransaction { recordLostSpan(with: .eventProcessor, quantity: currentSpanCount &+ 1) }
            } else if let transaction = processedEvent as? Transaction {
                recordPartiallyDroppedSpans(transaction, with: .eventProcessor, withCurrentSpanCount: &currentSpanCount)
            }
        }
        if let finalEvent = processedEvent, isFatalEvent && !SentrySDKInternal.lastRunStatusCalled {
            // Call only once even when sending several crash events.
            SentrySDKInternal.lastRunStatusCalled = true
            #if !SDK_V10
                options._onCrashedLastRun?(finalEvent)
            #endif
            options.onLastRunStatusDetermined?(.didCrash, finalEvent)
        }
        return processedEvent
    }
    @objc(recordPartiallyDroppedSpans:withReason:withCurrentSpanCount:)
    func recordPartiallyDroppedSpans(
        _ transaction: Transaction,
        with reason: SentryDiscardReason,
        withCurrentSpanCount currentSpanCount: UnsafeMutablePointer<UInt>
    ) {
        let spanCountAfter = UInt(transaction.spans.count)
        let droppedSpanCount = currentSpanCount.pointee &- spanCountAfter
        if droppedSpanCount > 0 { recordLostSpan(with: reason, quantity: droppedSpanCount) }
        currentSpanCount.pointee = spanCountAfter
    }
    func isSampled(_ sampleRate: NSNumber?) -> Bool {
        guard let sampleRate else { return false }
        return random.nextNumber() <= sampleRate.doubleValue ? false : true
    }
    /// Unlike isEnabled, this also checks options.enabled and whether a DSN was configured.
    /// Shared with metrics so all capture paths use the same disabled-client check.
    public var isDisabled: Bool { !isEnabled || !options.enabled || options.parsedDsn == nil }
    public func logDisabledMessage() { SentrySDKLog.debug("SDK disabled or no DSN set. Won't do anything.") }
    func callEventProcessors(_ event: Event) -> Event? {
        let newEvent = SentryDependencyContainer.sharedInstance().globalEventProcessor.reportAll(event)
        if newEvent == nil {
            SentrySDKLog.debug("SentryScope callEventProcessors: An event processor decided to remove this event.")
        }
        return newEvent
    }
    func setSdk(_ event: Event) {
        if event.sdk != nil { return }
        event.sdk = SentrySdkInfoObjC.optionsToDict(options)
    }
    @objc(setUserInfo:withEvent:)
    func setUserInfo(_ userInfo: [AnyHashable: Any]?, with event: Event?) {
        guard let event, let userInfo, !userInfo.isEmpty else { return }
        let hadContext = event.context != nil
        let context = NSMutableDictionary(dictionary: event.context ?? [:])
        context.setValue(sentry_sanitize_dictionary(userInfo), forKey: "user info")
        // The ObjC implementation mutates the newly assigned dictionary in place, but
        // does not assign its mutable copy back when the event already has a context.
        if !hadContext {
            event.context = context as? [String: [String: Any]]
        }
    }
    func setUserIdIfNoUserSet(_ event: Event) {
        #if SDK_V10
            if !options.dataCollection.userInfo { return }
        #endif
        if event.user == nil {
            let user = User()
            user.userId = SentryInstallation.id(withCacheDirectoryPath: options.cacheDirectoryPath)
            event.user = user
        }
    }
    func isWatchdogTermination(_ event: Event, isFatalEvent: Bool) -> Bool {
        if !isFatalEvent { return false }
        guard let exceptions = event.exceptions, exceptions.count == 1 else { return false }
        return exceptions[0].mechanism?.type == SentryWatchdogTerminationConstants.MechanismType
    }
    @objc(applyCultureContextToEvent:)
    func applyCultureContext(to event: Event) {
        modifyContext(event, key: "culture") { [self] culture in
            culture["calendar"] = locale.localizedString(forCalendarIdentifier: locale.calendarIdentifier)
            culture["display_name"] = locale.localizedString(forLocaleIdentifier: locale.localeIdentifier)
            culture["locale"] = locale.localeIdentifier
            culture["is_24_hour_format"] = SentryLocale.timeIs24HourFormat()
            culture["timezone"] = timezone.name
        }
    }
    @objc(applyExtraDeviceContextToEvent:)
    func applyExtraDeviceContext(to event: Event) {
        let extra = SentryDependencyContainer.sharedInstance().extraContextProvider.getExtraContext()
        modifyContext(event, key: "device") { device in
            if let context = extra["device"] as? [AnyHashable: Any] { device.addEntries(from: context) }
        }
        modifyContext(event, key: "app") { app in
            if let context = extra["app"] as? [AnyHashable: Any] { app.addEntries(from: context) }
        }
    }
    #if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
        @objc(applyCurrentViewNamesToEventContext:withScope:)
        func applyCurrentViewNamesToEventContext(_ event: Event, with scope: Scope) {
            modifyContext(event, key: "app") { app in
                if let transaction = event as? Transaction {
                    if !(transaction.viewNames?.isEmpty ?? true) { app["view_names"] = transaction.viewNames }
                } else if let currentScreen = scope.currentScreen {
                    app["view_names"] = [currentScreen]
                } else {
                    app["view_names"] = SentryDependencyContainer.sharedInstance().application()?
                        .relevantViewControllersNames()
                }
            }
        }
    #endif
    @objc(removeExtraDeviceContextFromEvent:)
    func removeExtraDeviceContext(from event: Event) {
        modifyContext(event, key: "device") { device in
            device.removeObject(forKey: SentryDeviceContextFreeMemoryKey)
            device.removeObject(forKey: "orientation")
            device.removeObject(forKey: "charging")
            device.removeObject(forKey: "battery_level")
            device.removeObject(forKey: "thermal_state")
        }
        modifyContext(event, key: "app") { app in app.removeObject(forKey: SentryDeviceContextAppMemoryKey) }
    }
    func modifyContext(_ event: Event, key: String, block: (NSMutableDictionary) -> Void) {
        guard let context = event.context, !context.isEmpty else { return }
        let mutableContext = NSMutableDictionary(dictionary: context)
        let dict = (context[key] as? NSDictionary)?.mutableCopy() as? NSMutableDictionary ?? NSMutableDictionary()
        block(dict)
        mutableContext[key] = dict
        event.context = mutableContext as? [String: [String: Any]]
    }
    func recordLost(_ eventIsNotATransaction: Bool, reason: SentryDiscardReason) {
        recordLostEvent(eventIsNotATransaction ? .error : .transaction, reason: reason)
    }
    @objc(recordLostSpanWithReason:quantity:)
    func recordLostSpan(with reason: SentryDiscardReason, quantity: UInt) {
        recordLostEvent(.span, reason: reason, quantity: quantity)
    }
    public func addAttachmentProcessor(_ attachmentProcessor: SentryClientAttachmentProcessor) {
        attachmentProcessors.add(attachmentProcessor)
    }
    public func removeAttachmentProcessor(_ attachmentProcessor: SentryClientAttachmentProcessor) {
        attachmentProcessors.remove(attachmentProcessor)
    }
    @objc(processAttachmentsForEvent:attachments:)
    func processAttachments(for event: Event, attachments: [Attachment]) -> [Attachment] {
        if attachmentProcessors.count == 0 { return attachments }
        var processedAttachments = attachments
        for processor in attachmentProcessors {
            // Each processor receives the preceding processor's output so it can add or remove
            // attachments. Processor order therefore depends on integration initialization order.
            processedAttachments = (processor as! SentryClientAttachmentProcessor).processAttachments(processedAttachments, for: event)
        }
        return processedAttachments
    }
    @objc(_swiftCaptureLog:withScope:)
    open func _swiftCaptureLog(_ log: NSObject, with scope: Scope) {
        let currentScope = currentScopeStorage.scope()
        _swiftCaptureLog(log, with: scope, currentScope: currentScope)
    }
    @objc(_swiftCaptureLog:withScope:currentScope:)
    func _swiftCaptureLog(_ log: NSObject, with scope: Scope, currentScope: Scope?) {
        if isDisabled { logDisabledMessage(); return }
        guard let log = log as? SentryLog else { return }
        // Custom attribute precedence is caller > current scope > global scope. Trace correlation,
        // user, and other reserved attributes come from the global scope only.
        let enrichedLog = logScopeApplier.applyScope(scope, currentScope: currentScope, toLog: log)
        var logToSend = enrichedLog
        if let callback = options.beforeSendLog {
            guard let processedLog = callback(enrichedLog) else {
                SentrySDKLog.debug("Log dropped by beforeSendLog callback.")
                recordDroppedLogInClientReport(enrichedLog)
                return
            }
            logToSend = processedLog
        }
        telemetryProcessor.add(log: logToSend)
    }
    func recordDroppedLogInClientReport(_ log: SentryLog) {
        recordDroppedItemInClientReport(withItemCategory: .logItem, byteCategory: .logByte) {
            SentryLogClientReport.serializedByteCount(for: log)
        }
    }
    @objc(recordDroppedTraceMetricInClientReport:)
    open func recordDroppedTraceMetric(inClientReport metric: SentryMetricObjC) {
        recordDroppedItemInClientReport(withItemCategory: .traceMetric, byteCategory: .traceMetricByte) {
            metric.serializedByteCount()
        }
    }
    @objc(recordDroppedItemInClientReportWithItemCategory:byteCategory:byteCountBlock:)
    func recordDroppedItemInClientReport(
        withItemCategory itemCategory: SentryDataCategory,
        byteCategory: SentryDataCategory,
        byteCountBlock: @escaping () -> UInt
    ) {
        // Serialization must stay off the calling thread of beforeSend.
        dispatchQueueWrapper.dispatchAsync { [weak self] in
            guard let self else { return }
            let byteCount = byteCountBlock()
            self.recordLostEvent(itemCategory, reason: .beforeSend)
            self.recordLostEvent(byteCategory, reason: .beforeSend, quantity: byteCount)
        }
    }
    open func getTelemetryProcessor() -> Any { telemetryProcessor }
}
// swiftlint:enable missing_docs file_length type_body_length function_body_length function_parameter_count cyclomatic_complexity force_cast
