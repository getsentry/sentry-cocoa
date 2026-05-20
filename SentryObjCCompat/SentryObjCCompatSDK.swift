// swiftlint:disable file_length
internal import SentrySwift
import Foundation

/// Pure-Swift `@objc` shim around `SentrySwift.SentrySDK`. Consumers that need
/// Objective-C interop should import `SentryObjCCompat` and call these APIs
/// instead of `SentrySDK` directly.
///
/// Imported as `SOCSentrySDK` from Objective-C.
@objc(SOCSentrySDK)
public final class SentryObjCCompatSDK: NSObject {

    private override init() { super.init() }

    // MARK: - Lifecycle

    @objc public static func start(options: Options) {
        SentrySwift.SentrySDK.start(options: options.wrapped)
    }

    @objc public static func start(configureOptions: @escaping (Options) -> Void) {
        let options = Options()
        configureOptions(options)
        SentrySwift.SentrySDK.start(options: options.wrapped)
    }

    @objc public static var isEnabled: Bool {
        SentrySwift.SentrySDK.isEnabled
    }

    @objc(flush:)
    public static func flush(timeout: TimeInterval) {
        SentrySwift.SentrySDK.flush(timeout: timeout)
    }

    @objc public static func close() {
        SentrySwift.SentrySDK.close()
    }

    // MARK: - Crash status

    @available(*, deprecated, message: "Use lastRunStatus instead, which distinguishes between 'did not crash' and 'unknown'.")
    @objc public static var crashedLastRun: Bool {
      SentrySwift.SentrySDK.crashedLastRun
    }

    @objc public static var lastRunStatus: SentryLastRunStatus {
        SentryLastRunStatus(SentrySwift.SentrySDK.lastRunStatus)
    }

    @objc public static var detectedStartUpCrash: Bool {
      SentrySwift.SentrySDK.detectedStartUpCrash
    }

    @objc public static func crash() {
      SentrySwift.SentrySDK.crash()
    }

    // MARK: - Sessions

    @objc public static func startSession() {
      SentrySwift.SentrySDK.startSession()
    }

    @objc public static func endSession() {
        SentrySwift.SentrySDK.endSession()
    }

    // MARK: - App-hang tracking

    @objc public static func pauseAppHangTracking() {
        SentrySwift.SentrySDK.pauseAppHangTracking()
    }

    @objc public static func resumeAppHangTracking() {
        SentrySwift.SentrySDK.resumeAppHangTracking()
    }

    // MARK: - UI lifecycle

    @objc public static func reportFullyDisplayed() {
        SentrySwift.SentrySDK.reportFullyDisplayed()
    }

    // MARK: - Tracing

    /// Current active transaction or span bound to the scope.
    @objc public static var span: Span? {
        SentrySwift.SentrySDK.span.map(Span.init)
    }

    @discardableResult
    @objc public static func startTransaction(name: String, operation: String) -> Span {
        Span(SentrySwift.SentrySDK.startTransaction(name: name, operation: operation))
    }

    @discardableResult
    @objc public static func startTransaction(
        name: String,
        operation: String,
        bindToScope: Bool
    ) -> Span {
        Span(SentrySwift.SentrySDK.startTransaction(
            name: name,
            operation: operation,
            bindToScope: bindToScope
        ))
    }

    @discardableResult
    @objc(startTransactionWithContext:)
    public static func startTransaction(transactionContext: TransactionContext) -> Span {
        Span(SentrySwift.SentrySDK.startTransaction(transactionContext: transactionContext.wrapped))
    }

    @discardableResult
    @objc(startTransactionWithContext:bindToScope:)
    public static func startTransaction(
        transactionContext: TransactionContext,
        bindToScope: Bool
    ) -> Span {
        Span(SentrySwift.SentrySDK.startTransaction(
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
        Span(SentrySwift.SentrySDK.startTransaction(
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
        Span(SentrySwift.SentrySDK.startTransaction(
            transactionContext: transactionContext.wrapped,
            customSamplingContext: customSamplingContext
        ))
    }

    // MARK: - Event capture

    @objc(captureEvent:)
    @discardableResult
    public static func capture(event: Event) -> SentryId {
        SentryId(SentrySwift.SentrySDK.capture(event: event.wrapped))
    }

    @objc(captureEvent:withScope:)
    @discardableResult
    public static func capture(event: Event, scope: Scope) -> SentryId {
        SentryId(SentrySwift.SentrySDK.capture(event: event.wrapped, scope: scope.wrapped))
    }

    @objc(captureEvent:withScopeBlock:)
    @discardableResult
    public static func capture(event: Event, block: @escaping (Scope) -> Void) -> SentryId {
        SentryId(SentrySwift.SentrySDK.capture(event: event.wrapped) { underlying in
            block(Scope(underlying))
        })
    }

    @objc(captureEvent:attachAllThreads:)
    @discardableResult
    public static func capture(event: Event, attachAllThreads: Bool) -> SentryId {
        SentryId(SentrySwift.SentrySDK.capture(event: event.wrapped, attachAllThreads: attachAllThreads))
    }

    // MARK: - Error capture

    @objc(captureError:)
    @discardableResult
    public static func capture(error: Error) -> SentryId {
        SentryId(SentrySwift.SentrySDK.capture(error: error))
    }

    @objc(captureError:withScope:)
    @discardableResult
    public static func capture(error: Error, scope: Scope) -> SentryId {
        SentryId(SentrySwift.SentrySDK.capture(error: error, scope: scope.wrapped))
    }

    @objc(captureError:withScopeBlock:)
    @discardableResult
    public static func capture(error: Error, block: @escaping (Scope) -> Void) -> SentryId {
        SentryId(SentrySwift.SentrySDK.capture(error: error) { underlying in
            block(Scope(underlying))
        })
    }

    @objc(captureError:attachAllThreads:)
    @discardableResult
    public static func capture(error: Error, attachAllThreads: Bool) -> SentryId {
        SentryId(SentrySwift.SentrySDK.capture(error: error, attachAllThreads: attachAllThreads))
    }

    // MARK: - Exception capture

    @objc(captureException:)
    @discardableResult
    public static func capture(exception: NSException) -> SentryId {
        SentryId(SentrySwift.SentrySDK.capture(exception: exception))
    }

    @objc(captureException:withScope:)
    @discardableResult
    public static func capture(exception: NSException, scope: Scope) -> SentryId {
        SentryId(SentrySwift.SentrySDK.capture(exception: exception, scope: scope.wrapped))
    }

    @objc(captureException:withScopeBlock:)
    @discardableResult
    public static func capture(
        exception: NSException,
        block: @escaping (Scope) -> Void
    ) -> SentryId {
        SentryId(SentrySwift.SentrySDK.capture(exception: exception) { underlying in
            block(Scope(underlying))
        })
    }

    @objc(captureException:attachAllThreads:)
    @discardableResult
    public static func capture(exception: NSException, attachAllThreads: Bool) -> SentryId {
        SentryId(SentrySwift.SentrySDK.capture(exception: exception, attachAllThreads: attachAllThreads))
    }

    // MARK: - Message capture

    @objc(captureMessage:)
    @discardableResult
    public static func capture(message: String) -> SentryId {
        SentryId(SentrySwift.SentrySDK.capture(message: message))
    }

    @objc(captureMessage:withScope:)
    @discardableResult
    public static func capture(message: String, scope: Scope) -> SentryId {
        SentryId(SentrySwift.SentrySDK.capture(message: message, scope: scope.wrapped))
    }

    @objc(captureMessage:withScopeBlock:)
    @discardableResult
    public static func capture(message: String, block: @escaping (Scope) -> Void) -> SentryId {
        SentryId(SentrySwift.SentrySDK.capture(message: message) { underlying in
            block(Scope(underlying))
        })
    }

    @objc(captureMessage:attachAllThreads:)
    @discardableResult
    public static func capture(message: String, attachAllThreads: Bool) -> SentryId {
        SentryId(SentrySwift.SentrySDK.capture(message: message, attachAllThreads: attachAllThreads))
    }

    // MARK: - Feedback

    @objc(captureFeedback:)
    public static func capture(feedback: Feedback) {
        SentrySwift.SentrySDK.capture(feedback: feedback.wrapped)
    }

    #if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
    /// The user-feedback API; iOS only.
    @objc public static var feedback: FeedbackAPI {
        FeedbackAPI(SentrySwift.SentrySDK.feedback)
    }
    #endif

    // MARK: - Breadcrumbs / scope / user

    @objc(addBreadcrumb:)
    public static func addBreadcrumb(_ crumb: Breadcrumb) {
        SentrySwift.SentrySDK.addBreadcrumb(crumb.wrapped)
    }

    @objc(configureScope:)
    public static func configureScope(_ callback: @escaping (Scope) -> Void) {
        SentrySwift.SentrySDK.configureScope { underlying in
            callback(Scope(underlying))
        }
    }

    @objc public static func setUser(_ user: User?) {
        SentrySwift.SentrySDK.setUser(user?.wrapped)
    }

    // MARK: - Continuous profiling

    #if !(os(watchOS) || os(tvOS) || os(visionOS))
    @objc public static func startProfiler() {
        SentrySwift.SentrySDK.startProfiler()
    }

    @objc public static func stopProfiler() {
        SentrySwift.SentrySDK.stopProfiler()
    }
    #endif

    // MARK: - Intentionally omitted in this pass
    //
    // TODO: wrap when SentryReplayApi is wrapped:    replay
    // TODO: wrap when SentryLogger is wrapped:       logger
    // TODO: wrap when SentryMetricsApi is wrapped:   metrics
}
// swiftlint:enable file_length
