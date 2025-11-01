@_implementationOnly import _SentryPrivate
import Foundation

@objc public final class SentryHub: NSObject {
    private let helper: SentryHubInternal
    @objc(initWithClient:andScope:) public init(client: SentryClient?, andScope scope: Scope?) {
        helper = SentryHubInternal(client: client?.helper, andScope: scope)
    }

    /**
     * Starts a new SentrySession. If there's a running SentrySession, it ends it before starting the
     * new one. You can use this method in combination with endSession to manually track SentrySessions.
     * The SDK uses SentrySession to inform Sentry about release and project associated project health.
     */
    @objc public func startSession() {
        helper.startSession()
    }

    /**
     * Ends the current SentrySession. You can use this method in combination with startSession to
     * manually track SentrySessions. The SDK uses SentrySession to inform Sentry about release and
     * project associated project health.
     */
    @objc public func endSession() {
        helper.endSession()
    }

    /**
     * Ends the current session with the given timestamp.
     * @param timestamp The timestamp to end the session with.
     */
    @objc public func endSession(withTimestamp timestamp: Date) {
        helper.endSession(withTimestamp: timestamp)
    }

    /**
     * Captures a manually created event and sends it to Sentry.
     * @param event The event to send to Sentry.
     * @return The SentryId of the event or SentryId.empty if the event is not sent.
     */
    @discardableResult @objc(captureEvent:) public func capture(event: Event) -> SentryId {
        helper.capture(event: event)
    }

    /**
     * Captures a manually created event and sends it to Sentry.
     * @param event The event to send to Sentry.
     * @param scope The scope containing event metadata.
     * @return The SentryId of the event or SentryId.empty if the event is not sent.
     */
    @discardableResult @objc(captureEvent:withScope:) public func capture(event: Event, scope: Scope) -> SentryId {
        helper.capture(event: event, scope: scope)
    }

    /**
     * Creates a transaction, binds it to the hub and returns the instance.
     * @param name The transaction name.
     * @param operation Short code identifying the type of operation the span is measuring.
     * @return The created transaction.
     */
    @discardableResult @objc public func startTransaction(name: String, operation: String) -> Span {
        helper.startTransaction(name: name, operation: operation)
    }

    /**
     * Creates a transaction, binds it to the hub and returns the instance.
     * @param name The transaction name.
     * @param operation Short code identifying the type of operation the span is measuring.
     * @param bindToScope Indicates whether the SDK should bind the new transaction to the scope.
     * @return The created transaction.
     */
    @discardableResult @objc public func startTransaction(name: String, operation: String, bindToScope: Bool) -> Span {
        helper.startTransaction(name: name, operation: operation, bindToScope: bindToScope)
    }

    /**
     * Creates a transaction, binds it to the hub and returns the instance.
     * @param transactionContext The transaction context.
     * @return The created transaction.
     */
    @discardableResult @objc(startTransactionWithContext:) public func startTransaction(transactionContext: TransactionContext) -> Span {
        helper.startTransaction(transactionContext: transactionContext)
    }

    /**
     * Creates a transaction, binds it to the hub and returns the instance.
     * @param transactionContext The transaction context.
     * @param bindToScope Indicates whether the SDK should bind the new transaction to the scope.
     * @return The created transaction.
     */
    @discardableResult @objc(startTransactionWithContext:bindToScope:) public func startTransaction(transactionContext: TransactionContext, bindToScope: Bool) -> Span {
        return helper.startTransaction(transactionContext: transactionContext, bindToScope: bindToScope)
    }

    /**
     * Creates a transaction, binds it to the hub and returns the instance.
     * @param transactionContext The transaction context.
     * @param bindToScope Indicates whether the SDK should bind the new transaction to the scope.
     * @param customSamplingContext Additional information about the sampling context.
     * @return The created transaction.
     */
    @discardableResult @objc(startTransactionWithContext:bindToScope:customSamplingContext:) public func startTransaction(
        transactionContext: TransactionContext,
        bindToScope: Bool,
        customSamplingContext: [String: Any]
    ) -> Span {
        return helper.startTransaction(
            transactionContext: transactionContext,
            bindToScope: bindToScope,
            customSamplingContext: customSamplingContext
        )
    }

    /**
     * Creates a transaction, binds it to the hub and returns the instance.
     * @param transactionContext The transaction context.
     * @param customSamplingContext Additional information about the sampling context.
     * @return The created transaction.
     */
    @discardableResult @objc(startTransactionWithContext:customSamplingContext:) public func startTransaction(
        transactionContext: TransactionContext,
        customSamplingContext: [String: Any]
    ) -> Span {
        return startTransaction(transactionContext: transactionContext, bindToScope: true, customSamplingContext: customSamplingContext)
    }

    /**
     * Captures an error event and sends it to Sentry.
     * @param error The error to send to Sentry.
     * @return The @c SentryId of the event or @c SentryId.empty if the event is not sent.
     */
    @discardableResult @objc(captureError:) public func capture(error: NSError) -> SentryId {
        helper.capture(error: error)
    }

    /**
     * Captures an error event and sends it to Sentry.
     * @param error The error to send to Sentry.
     * @param scope The scope containing event metadata.
     * @return The @c SentryId of the event or @c SentryId.empty if the event is not sent.
     */
    @discardableResult @objc(captureError:withScope:) public func capture(error: Error, scope: Scope) -> SentryId {
        helper.capture(error: error, scope: scope)
    }

    /**
     * Captures an exception event and sends it to Sentry.
     * @param exception The exception to send to Sentry.
     * @return The @c SentryId of the event or @c SentryId.empty if the event is not sent.
     */
    @discardableResult @objc(captureException:) public func capture(exception: NSException) -> SentryId {
        helper.capture(exception: exception)
    }

    /**
     * Captures an exception event and sends it to Sentry.
     * @param exception The exception to send to Sentry.
     * @param scope The scope containing event metadata.
     * @return The @c SentryId of the event or @c SentryId.empty if the event is not sent.
     */
    @discardableResult @objc(captureException:withScope:) public func capture(exception: NSException, scope: Scope) -> SentryId {
        helper.capture(exception: exception, scope: scope)
    }

    /**
     * Captures a message event and sends it to Sentry.
     * @param message The message to send to Sentry.
     * @return The @c SentryId of the event or @c SentryId.empty if the event is not sent.
     */
    @discardableResult @objc(captureMessage:) public func capture(message: String) -> SentryId {
        helper.capture(message: message)
    }

    /**
     * Captures a message event and sends it to Sentry.
     * @param message The message to send to Sentry.
     * @param scope The scope containing event metadata.
     * @return The @c SentryId of the event or @c SentryId.empty if the event is not sent.
     */
    @discardableResult @objc(captureMessage:withScope:) public func capture(message: String, scope: Scope) -> SentryId {
        helper.capture(message: message, scope: scope)
    }

    /**
     * Captures a new-style user feedback and sends it to Sentry.
     * @param feedback The user feedback to send to Sentry.
     */
    @objc(captureFeedback:) public func capture(feedback: SentryFeedback) {
        helper.captureSerializedFeedback(
          feedback.serialize(),
          withEventId: feedback.eventId.sentryIdString,
          attachments: feedback.attachmentsForEnvelope())
    }

    /**
     * Use this method to modify the Scope of the Hub. The SDK uses the Scope to attach
     * contextual data to events.
     * @param callback The callback for configuring the Scope of the Hub.
     */
    @objc public func configureScope(_ callback: @escaping (Scope) -> Void) {
        helper.configureScope(callback)
    }

    /**
     * Adds a breadcrumb to the Scope of the Hub.
     * @param crumb The Breadcrumb to add to the Scope of the Hub.
     */
    @objc(addBreadcrumb:) public func add(_ crumb: Breadcrumb) {
        helper.add(crumb)
    }

    /**
     * Returns a client if there is a bound client on the Hub.
     */
    @objc public func getClient() -> SentryClient? {
        if let client = self.helper.getClient() {
            return SentryClient(helper: client)
        }
        return nil
    }

    /**
     * Returns either the current scope or a new one if it was @c nil .
     */
    @objc public var scope: Scope {
        helper.scope
    }

    /**
     * Binds a different client to the hub.
     */
    @objc public func bindClient(_ client: SentryClient?) {
        helper.bindClient(client?.helper)
    }

    /**
     * Checks if integration is activated.
     */
    @objc public func hasIntegration(_ integrationName: String) -> Bool {
        helper.hasIntegration(integrationName)
    }

    /**
     * Checks if a specific Integration (@c integrationClass) has been installed.
     * @return @c YES if instance of @c integrationClass exists within
     * @c SentryHub.installedIntegrations
     */
    @objc public func isIntegrationInstalled(_ integrationClass: AnyClass) -> Bool {
        helper.isIntegrationInstalled(integrationClass)
    }

    /**
     * Set user to the Scope of the Hub.
     * @param user The user to set to the Scope.
     */
    @objc public func setUser(_ user: User?) {
        helper.setUser(user)
    }

    /**
     * Reports to the ongoing UIViewController transaction
     * that the screen contents are fully loaded and displayed,
     * which will create a new span.
     */
    @objc public func reportFullyDisplayed() {
        helper.reportFullyDisplayed()
    }

    /**
     * Waits synchronously for the SDK to flush out all queued and cached items for up to the specified
     * timeout in seconds. If there is no internet connection, the function returns immediately. The SDK
     * doesn't dispose the client or the hub.
     * @param timeout The time to wait for the SDK to complete the flush.
     */
    @objc(flush:) public func flush(timeout: TimeInterval) {
        helper.flush(timeout: timeout)
    }

    /**
     * Calls flush with @c SentryOptions/shutdownTimeInterval .
     */
    @objc public func close() {
        helper.close()
    }
    
    // MARK: Internal
    
    #if (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
    func getSessionReplayId() -> String? {
        helper.getSessionReplayId()
    }
    #endif
}
