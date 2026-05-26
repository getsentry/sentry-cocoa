// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

public final class SentryObjCHub: NSObject {
    internal let wrapped: SentryHub

    internal init(_ wrapped: SentryHub) {
        self.wrapped = wrapped
    }

    @objc public init(client: SentryObjCClient?, andScope scope: SentryObjCScope?) {
        self.wrapped = SentryHub(client: client?.wrapped, andScope: scope?.wrapped)
    }

    @objc public func startSession() {
        wrapped.startSession()
    }

    @objc public func endSession() {
        wrapped.endSession()
    }

    @objc public func endSession(withTimestamp timestamp: Date) {
        wrapped.endSession(withTimestamp: timestamp)
    }

    @discardableResult
    @objc(captureEvent:) public func capture(event: SentryObjCEvent) -> SentryObjCId {
        SentryObjCId(wrapped.capture(event: event.wrapped))
    }

    @discardableResult
    @objc(captureEvent:withScope:) public func capture(event: SentryObjCEvent, scope: SentryObjCScope) -> SentryObjCId {
        SentryObjCId(wrapped.capture(event: event.wrapped, scope: scope.wrapped))
    }

    @discardableResult
    @objc(captureError:) public func capture(error: NSError) -> SentryObjCId {
        SentryObjCId(wrapped.capture(error: error))
    }

    @discardableResult
    @objc(captureError:withScope:) public func capture(error: NSError, scope: SentryObjCScope) -> SentryObjCId {
        SentryObjCId(wrapped.capture(error: error, scope: scope.wrapped))
    }

    @discardableResult
    @objc(captureException:) public func capture(exception: NSException) -> SentryObjCId {
        SentryObjCId(wrapped.capture(exception: exception))
    }

    @discardableResult
    @objc(captureException:withScope:) public func capture(exception: NSException, scope: SentryObjCScope) -> SentryObjCId {
        SentryObjCId(wrapped.capture(exception: exception, scope: scope.wrapped))
    }

    @discardableResult
    @objc(captureMessage:) public func capture(message: String) -> SentryObjCId {
        SentryObjCId(wrapped.capture(message: message))
    }

    @discardableResult
    @objc(captureMessage:withScope:) public func capture(message: String, scope: SentryObjCScope) -> SentryObjCId {
        SentryObjCId(wrapped.capture(message: message, scope: scope.wrapped))
    }

    @objc(captureFeedback:) public func capture(feedback: SentryObjCFeedback) {
        wrapped.capture(feedback: feedback.wrapped)
    }

    @discardableResult
    @objc public func startTransaction(name: String, operation: String) -> SentryObjCSpan {
        SentryObjCSpan(wrapped.startTransaction(name: name, operation: operation))
    }

    @discardableResult
    @objc public func startTransaction(name: String, operation: String, bindToScope: Bool) -> SentryObjCSpan {
        SentryObjCSpan(wrapped.startTransaction(name: name, operation: operation, bindToScope: bindToScope))
    }

    @discardableResult
    @objc(startTransactionWithContext:) public func startTransaction(transactionContext: SentryObjCTransactionContext) -> SentryObjCSpan {
        SentryObjCSpan(wrapped.startTransaction(transactionContext: transactionContext.wrappedTransaction))
    }

    @discardableResult
    @objc(startTransactionWithContext:bindToScope:) public func startTransaction(transactionContext: SentryObjCTransactionContext, bindToScope: Bool) -> SentryObjCSpan {
        SentryObjCSpan(wrapped.startTransaction(transactionContext: transactionContext.wrappedTransaction, bindToScope: bindToScope))
    }

    @discardableResult
    @objc(startTransactionWithContext:bindToScope:customSamplingContext:) public func startTransaction(
        transactionContext: SentryObjCTransactionContext,
        bindToScope: Bool,
        customSamplingContext: [String: Any]
    ) -> SentryObjCSpan {
        SentryObjCSpan(wrapped.startTransaction(
            transactionContext: transactionContext.wrappedTransaction,
            bindToScope: bindToScope,
            customSamplingContext: customSamplingContext
        ))
    }

    @discardableResult
    @objc(startTransactionWithContext:customSamplingContext:) public func startTransaction(
        transactionContext: SentryObjCTransactionContext,
        customSamplingContext: [String: Any]
    ) -> SentryObjCSpan {
        SentryObjCSpan(wrapped.startTransaction(
            transactionContext: transactionContext.wrappedTransaction,
            customSamplingContext: customSamplingContext
        ))
    }

    @objc public func configureScope(_ callback: @escaping (SentryObjCScope) -> Void) {
        wrapped.configureScope { scope in
            callback(SentryObjCScope(scope))
        }
    }

    @objc(addBreadcrumb:) public func add(_ crumb: SentryObjCBreadcrumb) {
        wrapped.add(crumb.wrapped)
    }

    @objc public func getClient() -> SentryObjCClient? {
        guard let client = wrapped.getClient() else { return nil }
        return SentryObjCClient(client)
    }

    @objc public var scope: SentryObjCScope {
        SentryObjCScope(wrapped.scope)
    }

    @objc public func bindClient(_ client: SentryObjCClient?) {
        wrapped.bindClient(client?.wrapped)
    }

    @objc public func hasIntegration(_ integrationName: String) -> Bool {
        wrapped.hasIntegration(integrationName)
    }

    @objc public func isIntegrationInstalled(_ integrationClass: AnyClass) -> Bool {
        wrapped.isIntegrationInstalled(integrationClass)
    }

    @objc public func setUser(_ user: SentryObjCUser?) {
        wrapped.setUser(user?.wrapped)
    }

    @objc public func reportFullyDisplayed() {
        wrapped.reportFullyDisplayed()
    }

    @objc(flush:) public func flush(timeout: TimeInterval) {
        wrapped.flush(timeout: timeout)
    }

    @objc public func close() {
        wrapped.close()
    }
}

// swiftlint:enable missing_docs
