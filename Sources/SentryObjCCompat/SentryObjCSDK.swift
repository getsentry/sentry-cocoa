// swiftlint:disable missing_docs file_length type_body_length
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc(SentryObjCSDK) public final class SentryObjCSDK: NSObject {

    @objc public static var span: SentryObjCSpan? {
        guard let s = SentrySDK.span else { return nil }
        return SentryObjCSpan(s)
    }

    @objc public static var isEnabled: Bool {
        SentrySDK.isEnabled
    }

    #if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK && (os(iOS) || os(tvOS))
    @objc public static var replay: SentryObjCReplayApi {
        SentryObjCReplayApi(SentrySDK.replay)
    }
    #endif

    @objc public static var logger: SentryObjCLogger {
        SentryObjCLogger(SentrySDK.logger)
    }

    @objc public static var metrics: SentryObjCMetricsApi {
        SentryObjCMetricsApi(SentrySDK.metrics)
    }

    @objc public static var `internal`: SentryObjCInternalApi {
        SentryObjCInternalApi(SentrySDK.internal)
    }

    #if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
    @objc public static var feedback: SentryObjCFeedbackApi {
        SentryObjCFeedbackApi(SentrySDK.feedback)
    }
    #endif

    @objc public static func start(options: SentryObjCOptions) {
        SentryObjCSDKTracking.markStartedThroughObjCWrapper()
        SentrySDK.start(options: options.wrapped)
    }

    @objc public static func start(configureOptions: @escaping (SentryObjCOptions) -> Void) {
        SentryObjCSDKTracking.markStartedThroughObjCWrapper()
        SentrySDK.start { options in
            configureOptions(SentryObjCOptions(options))
        }
    }

    @objc(captureEvent:)
    @discardableResult public static func capture(event: SentryObjCEvent) -> SentryObjCId {
        SentryObjCId(SentrySDK.capture(event: event.wrapped))
    }

    @objc(captureEvent:withScope:)
    @discardableResult public static func capture(event: SentryObjCEvent, scope: SentryObjCScope) -> SentryObjCId {
        SentryObjCId(SentrySDK.capture(event: event.wrapped, scope: scope.wrapped))
    }

    @objc(captureEvent:withScopeBlock:)
    @discardableResult public static func capture(event: SentryObjCEvent, block: @escaping (SentryObjCScope) -> Void) -> SentryObjCId {
        SentryObjCId(SentrySDK.capture(event: event.wrapped) { scope in
            block(SentryObjCScope(scope))
        })
    }

    @objc(captureEvent:attachAllThreads:)
    @discardableResult public static func capture(event: SentryObjCEvent, attachAllThreads: Bool) -> SentryObjCId {
        SentryObjCId(SentrySDK.capture(event: event.wrapped, attachAllThreads: attachAllThreads))
    }

    @objc @discardableResult public static func startTransaction(name: String, operation: String) -> SentryObjCSpan {
        SentryObjCSpan(SentrySDK.startTransaction(name: name, operation: operation))
    }

    @objc @discardableResult public static func startTransaction(name: String, operation: String, bindToScope: Bool) -> SentryObjCSpan {
        SentryObjCSpan(SentrySDK.startTransaction(name: name, operation: operation, bindToScope: bindToScope))
    }

    @objc(startTransactionWithContext:)
    @discardableResult public static func startTransaction(transactionContext: SentryObjCTransactionContext) -> SentryObjCSpan {
        SentryObjCSpan(SentrySDK.startTransaction(transactionContext: transactionContext.wrappedTransaction))
    }

    @objc(startTransactionWithContext:bindToScope:)
    @discardableResult public static func startTransaction(transactionContext: SentryObjCTransactionContext, bindToScope: Bool) -> SentryObjCSpan {
        SentryObjCSpan(SentrySDK.startTransaction(transactionContext: transactionContext.wrappedTransaction, bindToScope: bindToScope))
    }

    @objc(startTransactionWithContext:bindToScope:customSamplingContext:)
    @discardableResult public static func startTransaction(transactionContext: SentryObjCTransactionContext, bindToScope: Bool, customSamplingContext: [String: Any]) -> SentryObjCSpan {
        SentryObjCSpan(SentrySDK.startTransaction(transactionContext: transactionContext.wrappedTransaction, bindToScope: bindToScope, customSamplingContext: customSamplingContext))
    }

    @objc(startTransactionWithContext:customSamplingContext:)
    @discardableResult public static func startTransaction(transactionContext: SentryObjCTransactionContext, customSamplingContext: [String: Any]) -> SentryObjCSpan {
        SentryObjCSpan(SentrySDK.startTransaction(transactionContext: transactionContext.wrappedTransaction, customSamplingContext: customSamplingContext))
    }

    @objc(captureError:)
    @discardableResult public static func capture(error: Error) -> SentryObjCId {
        SentryObjCId(SentrySDK.capture(error: error))
    }

    @objc(captureError:withScope:)
    @discardableResult public static func capture(error: Error, scope: SentryObjCScope) -> SentryObjCId {
        SentryObjCId(SentrySDK.capture(error: error, scope: scope.wrapped))
    }

    @objc(captureError:withScopeBlock:)
    @discardableResult public static func capture(error: Error, block: @escaping (SentryObjCScope) -> Void) -> SentryObjCId {
        SentryObjCId(SentrySDK.capture(error: error) { scope in
            block(SentryObjCScope(scope))
        })
    }

    @objc(captureError:attachAllThreads:)
    @discardableResult public static func capture(error: Error, attachAllThreads: Bool) -> SentryObjCId {
        SentryObjCId(SentrySDK.capture(error: error, attachAllThreads: attachAllThreads))
    }

    @objc(captureException:)
    @discardableResult public static func capture(exception: NSException) -> SentryObjCId {
        SentryObjCId(SentrySDK.capture(exception: exception))
    }

    @objc(captureException:withScope:)
    @discardableResult public static func capture(exception: NSException, scope: SentryObjCScope) -> SentryObjCId {
        SentryObjCId(SentrySDK.capture(exception: exception, scope: scope.wrapped))
    }

    @objc(captureException:withScopeBlock:)
    @discardableResult public static func capture(exception: NSException, block: @escaping (SentryObjCScope) -> Void) -> SentryObjCId {
        SentryObjCId(SentrySDK.capture(exception: exception) { scope in
            block(SentryObjCScope(scope))
        })
    }

    @objc(captureException:attachAllThreads:)
    @discardableResult public static func capture(exception: NSException, attachAllThreads: Bool) -> SentryObjCId {
        SentryObjCId(SentrySDK.capture(exception: exception, attachAllThreads: attachAllThreads))
    }

    @objc(captureMessage:)
    @discardableResult public static func capture(message: String) -> SentryObjCId {
        SentryObjCId(SentrySDK.capture(message: message))
    }

    @objc(captureMessage:withScope:)
    @discardableResult public static func capture(message: String, scope: SentryObjCScope) -> SentryObjCId {
        SentryObjCId(SentrySDK.capture(message: message, scope: scope.wrapped))
    }

    @objc(captureMessage:withScopeBlock:)
    @discardableResult public static func capture(message: String, block: @escaping (SentryObjCScope) -> Void) -> SentryObjCId {
        SentryObjCId(SentrySDK.capture(message: message) { scope in
            block(SentryObjCScope(scope))
        })
    }

    @objc(captureMessage:attachAllThreads:)
    @discardableResult public static func capture(message: String, attachAllThreads: Bool) -> SentryObjCId {
        SentryObjCId(SentrySDK.capture(message: message, attachAllThreads: attachAllThreads))
    }

    @objc(captureFeedbackWithMessage:name:email:source:associatedEventId:attachments:)
    public static func captureFeedback(message: String, name: String?, email: String?, source: SentryObjCFeedbackSource, associatedEventId: SentryObjCId?, attachments: [SentryObjCAttachment]?) {
        let feedback = SentryFeedback(
            message: message,
            name: name,
            email: email,
            source: source.underlying,
            associatedEventId: associatedEventId?.wrapped,
            attachments: attachments?.map(\.wrapped)
        )
        SentrySDK.capture(feedback: feedback)
    }

    @objc(addBreadcrumb:)
    public static func addBreadcrumb(_ crumb: SentryObjCBreadcrumb) {
        SentrySDK.addBreadcrumb(crumb.wrapped)
    }

    @objc(addFeatureFlagWithName:result:)
    public static func addFeatureFlag(name: String, result: Bool) {
        SentrySDK.addFeatureFlag(name: name, result: result)
    }

    @objc(removeFeatureFlagWithName:)
    public static func removeFeatureFlag(name: String) {
        SentrySDK.removeFeatureFlag(name: name)
    }

    @objc(configureScope:)
    public static func configureScope(_ callback: @escaping (SentryObjCScope) -> Void) {
        SentrySDK.configureScope { scope in
            callback(SentryObjCScope(scope))
        }
    }

#if !SDK_V10
    @available(*, deprecated, message: "Use lastRunStatus instead.")
    @objc public static var crashedLastRun: Bool {
        SentrySDK.crashedLastRun
    }
#endif

    @objc public static var lastRunStatus: SentryObjCLastRunStatus {
        SentryObjCLastRunStatus(SentrySDK.lastRunStatus)
    }

    @objc public static var detectedStartUpCrash: Bool {
        SentrySDK.detectedStartUpCrash
    }

    @objc public static func setUser(_ user: SentryObjCUser?) {
        SentrySDK.setUser(user?.wrapped)
    }

    @objc public static func startSession() {
        SentrySDK.startSession()
    }

    @objc public static func endSession() {
        SentrySDK.endSession()
    }

    @objc public static func crash() {
        SentrySDK.crash()
    }

    @objc public static func reportFullyDisplayed() {
        SentrySDK.reportFullyDisplayed()
    }

    #if !SENTRY_NO_UI_FRAMEWORK && (os(iOS) || os(tvOS) || os(visionOS))
    @objc public static func extendAppStart() {
        SentrySDK.extendAppStart()
    }

    @objc public static func getExtendedAppStartSpan() -> SentryObjCSpan? {
        guard let span = SentrySDK.getExtendedAppStartSpan() else { return nil }
        return SentryObjCSpan(span)
    }

    @objc public static func finishExtendedAppStart() {
        SentrySDK.finishExtendedAppStart()
    }
    #endif

    @objc public static func pauseAppHangTracking() {
        SentrySDK.pauseAppHangTracking()
    }

    @objc public static func resumeAppHangTracking() {
        SentrySDK.resumeAppHangTracking()
    }

    @objc(flush:)
    public static func flush(timeout: TimeInterval) {
        SentrySDK.flush(timeout: timeout)
    }

    @objc public static func close() {
        SentrySDK.close()
        SentryObjCSDKTracking.markClosedThroughObjCWrapper()
    }

    #if !(os(watchOS) || os(tvOS) || os(visionOS))
    @objc public static func startProfiler() {
        SentrySDK.startProfiler()
    }

    @objc public static func stopProfiler() {
        SentrySDK.stopProfiler()
    }
    #endif
}
// swiftlint:enable file_length type_body_length missing_docs
