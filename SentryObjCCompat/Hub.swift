internal import SentrySwift
import Foundation

/// Central manager for SDK configuration, event capture, and scope management.
@objc(SOCSentryHub)
public final class Hub: NSObject {
    internal let wrapped: SentrySwift.SentryHub

    internal init(_ wrapped: SentrySwift.SentryHub) {
        self.wrapped = wrapped
        super.init()
    }

    @objc(initWithClient:andScope:)
    public init(client: Client?, andScope scope: Scope?) {
        self.wrapped = SentrySwift.SentryHub(client: client?.wrapped, andScope: scope?.wrapped)
        super.init()
    }

    @objc public func startSession() { wrapped.startSession() }
    @objc public func endSession() { wrapped.endSession() }

    @objc(endSessionWithTimestamp:)
    public func endSession(timestamp: Date) {
        wrapped.endSession(withTimestamp: timestamp)
    }

    @objc(captureEvent:)
    @discardableResult
    public func capture(event: Event) -> SentryId {
        SentryId(wrapped.capture(event: event.wrapped))
    }

    @objc(captureEvent:withScope:)
    @discardableResult
    public func capture(event: Event, scope: Scope) -> SentryId {
        SentryId(wrapped.capture(event: event.wrapped, scope: scope.wrapped))
    }

    @discardableResult
    @objc public func startTransaction(name: String, operation: String) -> Span {
        Span(wrapped.startTransaction(name: name, operation: operation))
    }

    @discardableResult
    @objc public func startTransaction(name: String, operation: String, bindToScope: Bool) -> Span {
        Span(wrapped.startTransaction(name: name, operation: operation, bindToScope: bindToScope))
    }

    @discardableResult
    @objc(startTransactionWithContext:)
    public func startTransaction(transactionContext: TransactionContext) -> Span {
        Span(wrapped.startTransaction(transactionContext: transactionContext.wrapped))
    }

    @discardableResult
    @objc(startTransactionWithContext:bindToScope:)
    public func startTransaction(transactionContext: TransactionContext, bindToScope: Bool) -> Span {
        Span(wrapped.startTransaction(
            transactionContext: transactionContext.wrapped,
            bindToScope: bindToScope
        ))
    }

    @discardableResult
    @objc(startTransactionWithContext:bindToScope:customSamplingContext:)
    public func startTransaction(
        transactionContext: TransactionContext,
        bindToScope: Bool,
        customSamplingContext: [String: Any]
    ) -> Span {
        Span(wrapped.startTransaction(
            transactionContext: transactionContext.wrapped,
            bindToScope: bindToScope,
            customSamplingContext: customSamplingContext
        ))
    }

    @discardableResult
    @objc(startTransactionWithContext:customSamplingContext:)
    public func startTransaction(
        transactionContext: TransactionContext,
        customSamplingContext: [String: Any]
    ) -> Span {
        Span(wrapped.startTransaction(
            transactionContext: transactionContext.wrapped,
            customSamplingContext: customSamplingContext
        ))
    }

    @objc(captureError:)
    @discardableResult
    public func capture(error: Error) -> SentryId {
        SentryId(wrapped.capture(error: error as NSError))
    }

    @objc(captureError:withScope:)
    @discardableResult
    public func capture(error: Error, scope: Scope) -> SentryId {
        SentryId(wrapped.capture(error: error, scope: scope.wrapped))
    }

    @objc(captureException:)
    @discardableResult
    public func capture(exception: NSException) -> SentryId {
        SentryId(wrapped.capture(exception: exception))
    }

    @objc(captureException:withScope:)
    @discardableResult
    public func capture(exception: NSException, scope: Scope) -> SentryId {
        SentryId(wrapped.capture(exception: exception, scope: scope.wrapped))
    }

    @objc(captureMessage:)
    @discardableResult
    public func capture(message: String) -> SentryId {
        SentryId(wrapped.capture(message: message))
    }

    @objc(captureMessage:withScope:)
    @discardableResult
    public func capture(message: String, scope: Scope) -> SentryId {
        SentryId(wrapped.capture(message: message, scope: scope.wrapped))
    }

    @objc(captureFeedback:)
    public func capture(feedback: Feedback) {
        wrapped.capture(feedback: feedback.wrapped)
    }

    @objc public func configureScope(_ callback: @escaping (Scope) -> Void) {
        wrapped.configureScope { underlying in
            callback(Scope(underlying))
        }
    }

    @objc(addBreadcrumb:)
    public func add(_ crumb: Breadcrumb) {
        wrapped.add(crumb.wrapped)
    }

    @objc public func getClient() -> Client? {
        wrapped.getClient().map(Client.init)
    }

    @objc public var scope: Scope { Scope(wrapped.scope) }

    @objc public func bindClient(_ client: Client?) {
        wrapped.bindClient(client?.wrapped)
    }

    @objc public func hasIntegration(_ integrationName: String) -> Bool {
        wrapped.hasIntegration(integrationName)
    }

    @objc public func isIntegrationInstalled(_ integrationClass: AnyClass) -> Bool {
        wrapped.isIntegrationInstalled(integrationClass)
    }

    @objc public func setUser(_ user: User?) {
        wrapped.setUser(user?.wrapped)
    }

    @objc public func reportFullyDisplayed() {
        wrapped.reportFullyDisplayed()
    }

    @objc(flush:)
    public func flush(timeout: TimeInterval) {
        wrapped.flush(timeout: timeout)
    }

    @objc public func close() {
        wrapped.close()
    }
}
