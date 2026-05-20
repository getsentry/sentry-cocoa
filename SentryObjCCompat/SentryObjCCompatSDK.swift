// swiftlint:disable file_length
@_implementationOnly import Sentry
import Foundation

/// Pure-Swift `@objc` shim around `Sentry.SentrySDK`. Consumers that need
/// Objective-C interop should import `SentryObjCCompat` and call these APIs
/// instead of `SentrySDK` directly.
///
/// Imported as `SOCSentrySDK` from Objective-C.
@objc(SOCSentrySDK)
public final class SentryObjCCompatSDK: NSObject {

    private override init() { super.init() }

    // MARK: - Lifecycle

    @objc public static func start(options: Options) {
        Sentry.SentrySDK.start(options: options.wrapped)
    }

    @objc public static func start(configureOptions: @escaping (Options) -> Void) {
        let options = Options()
        configureOptions(options)
        Sentry.SentrySDK.start(options: options.wrapped)
    }

    @objc public static var isEnabled: Bool {
        Sentry.SentrySDK.isEnabled
    }

    @objc(flush:)
    public static func flush(timeout: TimeInterval) {
        Sentry.SentrySDK.flush(timeout: timeout)
    }

    @objc public static func close() {
        Sentry.SentrySDK.close()
    }

    // MARK: - Crash status

    @available(*, deprecated, message: "Use lastRunStatus instead, which distinguishes between 'did not crash' and 'unknown'.")
    @objc public static var crashedLastRun: Bool {
        Sentry.SentrySDK.crashedLastRun
    }

    @objc public static var lastRunStatus: SentryLastRunStatus {
        SentryLastRunStatus(Sentry.SentrySDK.lastRunStatus)
    }

    @objc public static var detectedStartUpCrash: Bool {
        Sentry.SentrySDK.detectedStartUpCrash
    }

    @objc public static func crash() {
        Sentry.SentrySDK.crash()
    }

    // MARK: - Sessions

    @objc public static func startSession() {
        Sentry.SentrySDK.startSession()
    }

    @objc public static func endSession() {
        Sentry.SentrySDK.endSession()
    }

    // MARK: - App-hang tracking

    @objc public static func pauseAppHangTracking() {
        Sentry.SentrySDK.pauseAppHangTracking()
    }

    @objc public static func resumeAppHangTracking() {
        Sentry.SentrySDK.resumeAppHangTracking()
    }

    // MARK: - UI lifecycle

    @objc public static func reportFullyDisplayed() {
        Sentry.SentrySDK.reportFullyDisplayed()
    }

    // MARK: - Tracing

    /// Current active transaction or span bound to the scope.
    @objc public static var span: Span? {
        Sentry.SentrySDK.span.map(Span.init)
    }

    @discardableResult
    @objc public static func startTransaction(name: String, operation: String) -> Span {
        Span(Sentry.SentrySDK.startTransaction(name: name, operation: operation))
    }

    @discardableResult
    @objc public static func startTransaction(
        name: String,
        operation: String,
        bindToScope: Bool
    ) -> Span {
        Span(Sentry.SentrySDK.startTransaction(
            name: name,
            operation: operation,
            bindToScope: bindToScope
        ))
    }

    @discardableResult
    @objc(startTransactionWithContext:)
    public static func startTransaction(transactionContext: TransactionContext) -> Span {
        Span(Sentry.SentrySDK.startTransaction(transactionContext: transactionContext.wrapped))
    }

    @discardableResult
    @objc(startTransactionWithContext:bindToScope:)
    public static func startTransaction(
        transactionContext: TransactionContext,
        bindToScope: Bool
    ) -> Span {
        Span(Sentry.SentrySDK.startTransaction(
            transactionContext: transactionContext.wrapped,
            bindToScope: bindToScope
        ))
    }

    @discardableResult
    @objc(startTransactionWithContext:bindToScope:customSamplingContext:)
    public static func startTransaction(
        transactionContext: TransactionContext,
        bindToScope: Bool,
        customSamplingContext: [String: Any]
    ) -> Span {
        Span(Sentry.SentrySDK.startTransaction(
            transactionContext: transactionContext.wrapped,
            bindToScope: bindToScope,
            customSamplingContext: customSamplingContext
        ))
    }

    @discardableResult
    @objc(startTransactionWithContext:customSamplingContext:)
    public static func startTransaction(
        transactionContext: TransactionContext,
        customSamplingContext: [String: Any]
    ) -> Span {
        Span(Sentry.SentrySDK.startTransaction(
            transactionContext: transactionContext.wrapped,
            customSamplingContext: customSamplingContext
        ))
    }

    // MARK: - Event capture

    @objc(captureEvent:)
    @discardableResult
    public static func capture(event: Event) -> SentryId {
        SentryId(Sentry.SentrySDK.capture(event: event.wrapped))
    }

    @objc(captureEvent:withScope:)
    @discardableResult
    public static func capture(event: Event, scope: Scope) -> SentryId {
        SentryId(Sentry.SentrySDK.capture(event: event.wrapped, scope: scope.wrapped))
    }

    @objc(captureEvent:withScopeBlock:)
    @discardableResult
    public static func capture(event: Event, block: @escaping (Scope) -> Void) -> SentryId {
        SentryId(Sentry.SentrySDK.capture(event: event.wrapped) { underlying in
            block(Scope(underlying))
        })
    }

    @objc(captureEvent:attachAllThreads:)
    @discardableResult
    public static func capture(event: Event, attachAllThreads: Bool) -> SentryId {
        SentryId(Sentry.SentrySDK.capture(event: event.wrapped, attachAllThreads: attachAllThreads))
    }

    // MARK: - Error capture

    @objc(captureError:)
    @discardableResult
    public static func capture(error: Error) -> SentryId {
        SentryId(Sentry.SentrySDK.capture(error: error))
    }

    @objc(captureError:withScope:)
    @discardableResult
    public static func capture(error: Error, scope: Scope) -> SentryId {
        SentryId(Sentry.SentrySDK.capture(error: error, scope: scope.wrapped))
    }

    @objc(captureError:withScopeBlock:)
    @discardableResult
    public static func capture(error: Error, block: @escaping (Scope) -> Void) -> SentryId {
        SentryId(Sentry.SentrySDK.capture(error: error) { underlying in
            block(Scope(underlying))
        })
    }

    @objc(captureError:attachAllThreads:)
    @discardableResult
    public static func capture(error: Error, attachAllThreads: Bool) -> SentryId {
        SentryId(Sentry.SentrySDK.capture(error: error, attachAllThreads: attachAllThreads))
    }

    // MARK: - Exception capture

    @objc(captureException:)
    @discardableResult
    public static func capture(exception: NSException) -> SentryId {
        SentryId(Sentry.SentrySDK.capture(exception: exception))
    }

    @objc(captureException:withScope:)
    @discardableResult
    public static func capture(exception: NSException, scope: Scope) -> SentryId {
        SentryId(Sentry.SentrySDK.capture(exception: exception, scope: scope.wrapped))
    }

    @objc(captureException:withScopeBlock:)
    @discardableResult
    public static func capture(
        exception: NSException,
        block: @escaping (Scope) -> Void
    ) -> SentryId {
        SentryId(Sentry.SentrySDK.capture(exception: exception) { underlying in
            block(Scope(underlying))
        })
    }

    @objc(captureException:attachAllThreads:)
    @discardableResult
    public static func capture(exception: NSException, attachAllThreads: Bool) -> SentryId {
        SentryId(Sentry.SentrySDK.capture(exception: exception, attachAllThreads: attachAllThreads))
    }

    // MARK: - Message capture

    @objc(captureMessage:)
    @discardableResult
    public static func capture(message: String) -> SentryId {
        SentryId(Sentry.SentrySDK.capture(message: message))
    }

    @objc(captureMessage:withScope:)
    @discardableResult
    public static func capture(message: String, scope: Scope) -> SentryId {
        SentryId(Sentry.SentrySDK.capture(message: message, scope: scope.wrapped))
    }

    @objc(captureMessage:withScopeBlock:)
    @discardableResult
    public static func capture(message: String, block: @escaping (Scope) -> Void) -> SentryId {
        SentryId(Sentry.SentrySDK.capture(message: message) { underlying in
            block(Scope(underlying))
        })
    }

    @objc(captureMessage:attachAllThreads:)
    @discardableResult
    public static func capture(message: String, attachAllThreads: Bool) -> SentryId {
        SentryId(Sentry.SentrySDK.capture(message: message, attachAllThreads: attachAllThreads))
    }

    // MARK: - Feedback

    @objc(captureFeedback:)
    public static func capture(feedback: Feedback) {
        Sentry.SentrySDK.capture(feedback: feedback.wrapped)
    }

    #if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
    /// The user-feedback API; iOS only.
    @objc public static var feedback: FeedbackAPI {
        FeedbackAPI(Sentry.SentrySDK.feedback)
    }
    #endif

    // MARK: - Breadcrumbs / scope / user

    @objc(addBreadcrumb:)
    public static func addBreadcrumb(_ crumb: Breadcrumb) {
        Sentry.SentrySDK.addBreadcrumb(crumb.wrapped)
    }

    @objc(configureScope:)
    public static func configureScope(_ callback: @escaping (Scope) -> Void) {
        Sentry.SentrySDK.configureScope { underlying in
            callback(Scope(underlying))
        }
    }

    @objc public static func setUser(_ user: User?) {
        Sentry.SentrySDK.setUser(user?.wrapped)
    }

    // MARK: - Continuous profiling

    #if !(os(watchOS) || os(tvOS) || os(visionOS))
    @objc public static func startProfiler() {
        Sentry.SentrySDK.startProfiler()
    }

    @objc public static func stopProfiler() {
        Sentry.SentrySDK.stopProfiler()
    }
    #endif

    // MARK: - Intentionally omitted in this pass
    //
    // TODO: wrap when SentryReplayApi is wrapped:    replay
    // TODO: wrap when SentryLogger is wrapped:       logger
    // TODO: wrap when SentryMetricsApi is wrapped:   metrics
}
// swiftlint:enable file_length
