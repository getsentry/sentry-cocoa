// swiftlint:disable missing_docs
import Foundation
import SentryObjCTypes

#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif

// TYPE-ERASING LIMITATION
// -----------------------
// This class is the central bridge between the pure-ObjC SentryObjC facade
// and the Swift SDK.  Because SentryObjCCompat uses internal import
// import, NO type from the Sentry/SentrySwift module may appear in a public
// or @usableFromInline signature.  That means:
//
//   - Every parameter/return that would naturally be a typed SDK class
//     (Event, Scope, Options, Breadcrumb, User, TransactionContext,
//     SentryFeedback, SentryId, etc.) is declared as NSObject.
//   - Every method body uses `guard let x = param as? RealType` to
//     downcast at runtime.  Invalid types cause the method to silently
//     return a default (SentryId.empty, NSObject(), or early-return).
//   - Scope/Options callback closures take (NSObject) -> Void instead
//     of (Scope) -> Void / (Options) -> Void.
//
// What this costs:
//   - ObjC consumers lose compile-time type safety on every SDK object
//     they pass through the bridge.  The SentryObjC facade's hand-written
//     .m files enforce correct types at the ObjC call site, but the
//     bridge itself cannot verify them at compile time.
//   - If an ObjC call site passes the wrong NSObject subclass, the
//     guard-let fails silently instead of producing a compile error.
//
// Why it's necessary:
//   Without internal import, the SentryObjCCompat module would
//   re-export Sentry's Swift types in its .swiftmodule.  Any consumer
//   linking SentryObjCCompat would then need the Swift runtime and
//   Sentry's *-Swift.h — exactly what the pure-ObjC wrapper exists to
//   avoid.
//
// The alternative — adding @objc(ClassName) to each affected Swift class
// — eliminates the need for type-erased wrappers entirely, because the
// ObjC .m files could then use forward-declared @interface with the real
// class name and the linker resolves it.  That approach modifies existing
// SDK source files.
@objc(SentryObjCBridge)
public final class SentryObjCBridge: NSObject {

    // MARK: - SDK API

    @objc public static var sdkSpan: (any NSObjectProtocol)? {
        return SentrySDK.span as? NSObject
    }

    @objc public static var sdkIsEnabled: Bool {
        return SentrySDK.isEnabled
    }

    @objc public static var sdkLastRunStatus: Int {
        return SentrySDK.lastRunStatus.rawValue
    }

    @objc public static func sdkStart(options: NSObject) {
        guard let opts = options as? Options else { return }
        SentrySDK.start(options: opts)
    }

    @objc public static func sdkStart(configureOptions: @escaping (NSObject) -> Void) {
        SentrySDK.start { options in
            configureOptions(options)
        }
    }

    @objc public static func sdkCaptureEvent(_ event: NSObject) -> NSObject {
        guard let e = event as? Event else { return SentryId.empty }
        return SentrySDK.capture(event: e)
    }

    @objc public static func sdkCaptureEvent(_ event: NSObject, withScope scope: NSObject) -> NSObject {
        guard let e = event as? Event, let s = scope as? Scope else { return SentryId.empty }
        return SentrySDK.capture(event: e, scope: s)
    }

    @objc public static func sdkCaptureEvent(_ event: NSObject, withScopeBlock block: @escaping (NSObject) -> Void) -> NSObject {
        guard let e = event as? Event else { return SentryId.empty }
        return SentrySDK.capture(event: e) { scope in
            block(scope)
        }
    }

    @objc public static func sdkCaptureEvent(_ event: NSObject, attachAllThreads: Bool) -> NSObject {
        guard let e = event as? Event else { return SentryId.empty }
        return SentrySDK.capture(event: e, attachAllThreads: attachAllThreads)
    }

    @objc public static func sdkStartTransaction(name: String, operation: String) -> NSObject {
        // swiftlint:disable:next force_cast
        return SentrySDK.startTransaction(name: name, operation: operation) as! NSObject
    }

    @objc public static func sdkStartTransaction(name: String, operation: String, bindToScope: Bool) -> NSObject {
        // swiftlint:disable:next force_cast
        return SentrySDK.startTransaction(name: name, operation: operation, bindToScope: bindToScope) as! NSObject
    }

    @objc(sdkStartTransactionWithContext:)
    public static func sdkStartTransaction(transactionContext: NSObject) -> NSObject {
        guard let ctx = transactionContext as? TransactionContext else { return NSObject() }
        // swiftlint:disable:next force_cast
        return SentrySDK.startTransaction(transactionContext: ctx) as! NSObject
    }

    @objc(sdkStartTransactionWithContext:bindToScope:)
    public static func sdkStartTransaction(transactionContext: NSObject, bindToScope: Bool) -> NSObject {
        guard let ctx = transactionContext as? TransactionContext else { return NSObject() }
        // swiftlint:disable:next force_cast
        return SentrySDK.startTransaction(transactionContext: ctx, bindToScope: bindToScope) as! NSObject
    }

    @objc(sdkStartTransactionWithContext:customSamplingContext:)
    public static func sdkStartTransaction(transactionContext: NSObject, customSamplingContext: [String: Any]) -> NSObject {
        guard let ctx = transactionContext as? TransactionContext else { return NSObject() }
        // swiftlint:disable:next force_cast
        return SentrySDK.startTransaction(transactionContext: ctx, customSamplingContext: customSamplingContext) as! NSObject
    }

    @objc(sdkStartTransactionWithContext:bindToScope:customSamplingContext:)
    public static func sdkStartTransaction(transactionContext: NSObject, bindToScope: Bool, customSamplingContext: [String: Any]) -> NSObject {
        guard let ctx = transactionContext as? TransactionContext else { return NSObject() }
        // swiftlint:disable:next force_cast
        return SentrySDK.startTransaction(transactionContext: ctx, bindToScope: bindToScope, customSamplingContext: customSamplingContext) as! NSObject
    }

    @objc public static func sdkCaptureError(_ error: any Error) -> NSObject {
        return SentrySDK.capture(error: error)
    }

    @objc public static func sdkCaptureError(_ error: any Error, withScope scope: NSObject) -> NSObject {
        guard let s = scope as? Scope else { return SentryId.empty }
        return SentrySDK.capture(error: error, scope: s)
    }

    @objc public static func sdkCaptureError(_ error: any Error, withScopeBlock block: @escaping (NSObject) -> Void) -> NSObject {
        return SentrySDK.capture(error: error) { scope in
            block(scope)
        }
    }

    @objc public static func sdkCaptureError(_ error: any Error, attachAllThreads: Bool) -> NSObject {
        return SentrySDK.capture(error: error, attachAllThreads: attachAllThreads)
    }

    @objc public static func sdkCaptureException(_ exception: NSException) -> NSObject {
        return SentrySDK.capture(exception: exception)
    }

    @objc public static func sdkCaptureException(_ exception: NSException, withScope scope: NSObject) -> NSObject {
        guard let s = scope as? Scope else { return SentryId.empty }
        return SentrySDK.capture(exception: exception, scope: s)
    }

    @objc public static func sdkCaptureException(_ exception: NSException, withScopeBlock block: @escaping (NSObject) -> Void) -> NSObject {
        return SentrySDK.capture(exception: exception) { scope in
            block(scope)
        }
    }

    @objc public static func sdkCaptureException(_ exception: NSException, attachAllThreads: Bool) -> NSObject {
        return SentrySDK.capture(exception: exception, attachAllThreads: attachAllThreads)
    }

    @objc public static func sdkCaptureMessage(_ message: String) -> NSObject {
        return SentrySDK.capture(message: message)
    }

    @objc public static func sdkCaptureMessage(_ message: String, withScope scope: NSObject) -> NSObject {
        guard let s = scope as? Scope else { return SentryId.empty }
        return SentrySDK.capture(message: message, scope: s)
    }

    @objc public static func sdkCaptureMessage(_ message: String, withScopeBlock block: @escaping (NSObject) -> Void) -> NSObject {
        return SentrySDK.capture(message: message) { scope in
            block(scope)
        }
    }

    @objc public static func sdkCaptureMessage(_ message: String, attachAllThreads: Bool) -> NSObject {
        return SentrySDK.capture(message: message, attachAllThreads: attachAllThreads)
    }

    @objc public static func sdkCaptureFeedback(_ feedback: NSObject) {
        guard let f = feedback as? SentryFeedback else { return }
        SentrySDK.capture(feedback: f)
    }

    @objc public static func sdkAddBreadcrumb(_ crumb: NSObject) {
        guard let b = crumb as? Breadcrumb else { return }
        SentrySDK.addBreadcrumb(b)
    }

    @objc public static func sdkConfigureScope(_ callback: @escaping (NSObject) -> Void) {
        SentrySDK.configureScope { scope in
            callback(scope)
        }
    }

    @available(*, deprecated, message: "Use lastRunStatus instead.")
    @objc public static var sdkCrashedLastRun: Bool {
        return SentrySDK.crashedLastRun
    }

    @objc public static var sdkDetectedStartUpCrash: Bool {
        return SentrySDK.detectedStartUpCrash
    }

    @objc public static func sdkSetUser(_ user: NSObject?) {
        SentrySDK.setUser(user as? User)
    }

    @objc public static func sdkStartSession() {
        SentrySDK.startSession()
    }

    @objc public static func sdkEndSession() {
        SentrySDK.endSession()
    }

    @objc public static func sdkCrash() {
        SentrySDK.crash()
    }

    @objc public static func sdkReportFullyDisplayed() {
        SentrySDK.reportFullyDisplayed()
    }

    @objc public static func sdkPauseAppHangTracking() {
        SentrySDK.pauseAppHangTracking()
    }

    @objc public static func sdkResumeAppHangTracking() {
        SentrySDK.resumeAppHangTracking()
    }

    @objc public static func sdkFlush(timeout: TimeInterval) {
        SentrySDK.flush(timeout: timeout)
    }

    @objc public static func sdkClose() {
        SentrySDK.close()
    }

    #if !(os(watchOS) || os(tvOS) || os(visionOS))
    @objc public static func sdkStartProfiler() {
        SentrySDK.startProfiler()
    }

    @objc public static func sdkStopProfiler() {
        SentrySDK.stopProfiler()
    }
    #endif

    // MARK: - Metrics API

    @objc public static func metricsCount(
        key: String,
        value: UInt,
        attributes: [String: SentryObjCAttributeContent]
    ) {
        SentrySDK.metrics.count(key: key, value: value, attributes: attributes.mapValues { $0.toAttributeValue() })
    }

    @objc public static func metricsDistribution(
        key: String,
        value: Double,
        unit: String?,
        attributes: [String: SentryObjCAttributeContent]
    ) {
        let swiftUnit = unit.flatMap { SentryUnit(rawValue: $0) }
        SentrySDK.metrics.distribution(key: key, value: value, unit: swiftUnit, attributes: attributes.mapValues { $0.toAttributeValue() })
    }

    @objc public static func metricsGauge(
        key: String,
        value: Double,
        unit: String?,
        attributes: [String: SentryObjCAttributeContent]
    ) {
        let swiftUnit = unit.flatMap { SentryUnit(rawValue: $0) }
        SentrySDK.metrics.gauge(key: key, value: value, unit: swiftUnit, attributes: attributes.mapValues { $0.toAttributeValue() })
    }

    // MARK: - Logger API

    @objc public static var logger: NSObject {
        return SentrySDK.logger
    }

    // MARK: - Feedback API

    #if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
    @objc public static var sdkFeedback: NSObject {
        return SentrySDK.feedback
    }
    #endif

    // MARK: - Replay API

    #if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK && (os(iOS) || os(tvOS))
    @objc public static var replay: NSObject {
        return SentrySDK.replay
    }
    #endif
}
