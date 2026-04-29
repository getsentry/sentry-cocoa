import Foundation
import SentryObjCTypes

// Import the Sentry SDK module.
// SPM uses SentrySwift, Xcode uses Sentry.
#if SWIFT_PACKAGE
import SentrySwift
#else
import Sentry
#endif

/// Bridge class that exposes Swift SDK functionality to pure Objective-C code.
///
/// This class provides @objc methods that can be called from SentryObjC (pure ObjC, no modules)
/// and forwards them to the Swift SentrySDK implementation. Conformance to
/// `SentryObjCBridging` (declared in `SentryObjCTypes/Public/SentryObjCBridging.h`) is
/// the contract that prevents drift between the .m's call sites and this bridge's
/// `@objc` emission.
@objc(SentryObjCBridge)
public final class SentrySwiftBridge: NSObject {

    // MARK: - SDK API

    /// Bridge for `SentrySDK.span`.
    @objc public static var sdkSpan: Span? {
        return SentrySDK.span
    }

    /// Bridge for `SentrySDK.isEnabled`.
    @objc public static var sdkIsEnabled: Bool {
        return SentrySDK.isEnabled
    }

    /// Bridge for `SentrySDK.lastRunStatus`.
    @objc public static var sdkLastRunStatus: Int {
        return SentrySDK.lastRunStatus.rawValue
    }

    /// Bridge for `SentrySDK.start(options:)`.
    @objc public static func sdkStart(options: Options) {
        SentrySDK.start(options: options)
    }

    /// Bridge for `SentrySDK.start(configureOptions:)`.
    @objc public static func sdkStart(configureOptions: @escaping (Options) -> Void) {
        SentrySDK.start(configureOptions: configureOptions)
    }

    /// Bridge for `SentrySDK.capture(event:)`.
    @objc public static func sdkCaptureEvent(_ event: Event) -> SentryId {
        return SentrySDK.capture(event: event)
    }

    /// Bridge for `SentrySDK.capture(event:scope:)`.
    @objc public static func sdkCaptureEvent(_ event: Event, withScope scope: Scope) -> SentryId {
        return SentrySDK.capture(event: event, scope: scope)
    }

    /// Bridge for `SentrySDK.capture(event:block:)`.
    @objc public static func sdkCaptureEvent(_ event: Event, withScopeBlock block: @escaping (Scope) -> Void) -> SentryId {
        return SentrySDK.capture(event: event, block: block)
    }

    /// Bridge for `SentrySDK.capture(event:attachAllThreads:)`.
    @objc public static func sdkCaptureEvent(_ event: Event, attachAllThreads: Bool) -> SentryId {
        return SentrySDK.capture(event: event, attachAllThreads: attachAllThreads)
    }

    /// Bridge for `SentrySDK.startTransaction(name:operation:)`.
    @objc public static func sdkStartTransaction(name: String, operation: String) -> Span {
        return SentrySDK.startTransaction(name: name, operation: operation)
    }

    /// Bridge for `SentrySDK.startTransaction(name:operation:bindToScope:)`.
    @objc public static func sdkStartTransaction(name: String, operation: String, bindToScope: Bool) -> Span {
        return SentrySDK.startTransaction(name: name, operation: operation, bindToScope: bindToScope)
    }

    /// Bridge for `SentrySDK.startTransaction(transactionContext:)`.
    @objc(sdkStartTransactionWithContext:)
    public static func sdkStartTransaction(transactionContext: TransactionContext) -> Span {
        return SentrySDK.startTransaction(transactionContext: transactionContext)
    }

    /// Bridge for `SentrySDK.startTransaction(transactionContext:bindToScope:)`.
    @objc(sdkStartTransactionWithContext:bindToScope:)
    public static func sdkStartTransaction(transactionContext: TransactionContext, bindToScope: Bool) -> Span {
        return SentrySDK.startTransaction(transactionContext: transactionContext, bindToScope: bindToScope)
    }

    /// Bridge for `SentrySDK.startTransaction(transactionContext:customSamplingContext:)`.
    @objc(sdkStartTransactionWithContext:customSamplingContext:)
    public static func sdkStartTransaction(transactionContext: TransactionContext, customSamplingContext: [String: Any]) -> Span {
        return SentrySDK.startTransaction(transactionContext: transactionContext, customSamplingContext: customSamplingContext)
    }

    /// Bridge for `SentrySDK.startTransaction(transactionContext:bindToScope:customSamplingContext:)`.
    @objc(sdkStartTransactionWithContext:bindToScope:customSamplingContext:)
    public static func sdkStartTransaction(transactionContext: TransactionContext, bindToScope: Bool, customSamplingContext: [String: Any]) -> Span {
        return SentrySDK.startTransaction(transactionContext: transactionContext, bindToScope: bindToScope, customSamplingContext: customSamplingContext)
    }

    /// Bridge for `SentrySDK.capture(error:)`.
    @objc public static func sdkCaptureError(_ error: any Error) -> SentryId {
        return SentrySDK.capture(error: error)
    }

    /// Bridge for `SentrySDK.capture(error:scope:)`.
    @objc public static func sdkCaptureError(_ error: any Error, withScope scope: Scope) -> SentryId {
        return SentrySDK.capture(error: error, scope: scope)
    }

    /// Bridge for `SentrySDK.capture(error:block:)`.
    @objc public static func sdkCaptureError(_ error: any Error, withScopeBlock block: @escaping (Scope) -> Void) -> SentryId {
        return SentrySDK.capture(error: error, block: block)
    }

    /// Bridge for `SentrySDK.capture(error:attachAllThreads:)`.
    @objc public static func sdkCaptureError(_ error: any Error, attachAllThreads: Bool) -> SentryId {
        return SentrySDK.capture(error: error, attachAllThreads: attachAllThreads)
    }

    /// Bridge for `SentrySDK.capture(exception:)`.
    @objc public static func sdkCaptureException(_ exception: NSException) -> SentryId {
        return SentrySDK.capture(exception: exception)
    }

    /// Bridge for `SentrySDK.capture(exception:scope:)`.
    @objc public static func sdkCaptureException(_ exception: NSException, withScope scope: Scope) -> SentryId {
        return SentrySDK.capture(exception: exception, scope: scope)
    }

    /// Bridge for `SentrySDK.capture(exception:block:)`.
    @objc public static func sdkCaptureException(_ exception: NSException, withScopeBlock block: @escaping (Scope) -> Void) -> SentryId {
        return SentrySDK.capture(exception: exception, block: block)
    }

    /// Bridge for `SentrySDK.capture(exception:attachAllThreads:)`.
    @objc public static func sdkCaptureException(_ exception: NSException, attachAllThreads: Bool) -> SentryId {
        return SentrySDK.capture(exception: exception, attachAllThreads: attachAllThreads)
    }

    /// Bridge for `SentrySDK.capture(message:)`.
    @objc public static func sdkCaptureMessage(_ message: String) -> SentryId {
        return SentrySDK.capture(message: message)
    }

    /// Bridge for `SentrySDK.capture(message:scope:)`.
    @objc public static func sdkCaptureMessage(_ message: String, withScope scope: Scope) -> SentryId {
        return SentrySDK.capture(message: message, scope: scope)
    }

    /// Bridge for `SentrySDK.capture(message:block:)`.
    @objc public static func sdkCaptureMessage(_ message: String, withScopeBlock block: @escaping (Scope) -> Void) -> SentryId {
        return SentrySDK.capture(message: message, block: block)
    }

    /// Bridge for `SentrySDK.capture(message:attachAllThreads:)`.
    @objc public static func sdkCaptureMessage(_ message: String, attachAllThreads: Bool) -> SentryId {
        return SentrySDK.capture(message: message, attachAllThreads: attachAllThreads)
    }

    /// Bridge for `SentrySDK.capture(feedback:)`.
    @objc public static func sdkCaptureFeedback(_ feedback: SentryFeedback) {
        SentrySDK.capture(feedback: feedback)
    }

    /// Bridge for `SentrySDK.addBreadcrumb(_:)`.
    @objc public static func sdkAddBreadcrumb(_ crumb: Breadcrumb) {
        SentrySDK.addBreadcrumb(crumb)
    }

    /// Bridge for `SentrySDK.configureScope(_:)`.
    @objc public static func sdkConfigureScope(_ callback: @escaping (Scope) -> Void) {
        SentrySDK.configureScope(callback)
    }

    /// Bridge for `SentrySDK.crashedLastRun`.
    @available(*, deprecated, message: "Use lastRunStatus instead, which distinguishes between 'did not crash' and 'unknown'.")
    @objc public static var sdkCrashedLastRun: Bool {
        return SentrySDK.crashedLastRun
    }

    /// Bridge for `SentrySDK.detectedStartUpCrash`.
    @objc public static var sdkDetectedStartUpCrash: Bool {
        return SentrySDK.detectedStartUpCrash
    }

    /// Bridge for `SentrySDK.setUser(_:)`.
    @objc public static func sdkSetUser(_ user: User?) {
        SentrySDK.setUser(user)
    }

    /// Bridge for `SentrySDK.startSession()`.
    @objc public static func sdkStartSession() {
        SentrySDK.startSession()
    }

    /// Bridge for `SentrySDK.endSession()`.
    @objc public static func sdkEndSession() {
        SentrySDK.endSession()
    }

    /// Bridge for `SentrySDK.crash()`.
    @objc public static func sdkCrash() {
        SentrySDK.crash()
    }

    /// Bridge for `SentrySDK.reportFullyDisplayed()`.
    @objc public static func sdkReportFullyDisplayed() {
        SentrySDK.reportFullyDisplayed()
    }

    /// Bridge for `SentrySDK.pauseAppHangTracking()`.
    @objc public static func sdkPauseAppHangTracking() {
        SentrySDK.pauseAppHangTracking()
    }

    /// Bridge for `SentrySDK.resumeAppHangTracking()`.
    @objc public static func sdkResumeAppHangTracking() {
        SentrySDK.resumeAppHangTracking()
    }

    /// Bridge for `SentrySDK.flush(timeout:)`.
    @objc public static func sdkFlush(timeout: TimeInterval) {
        SentrySDK.flush(timeout: timeout)
    }

    /// Bridge for `SentrySDK.close()`.
    @objc public static func sdkClose() {
        SentrySDK.close()
    }

    #if !(os(watchOS) || os(tvOS) || os(visionOS))
    /// Bridge for `SentrySDK.startProfiler()`.
    @objc public static func sdkStartProfiler() {
        SentrySDK.startProfiler()
    }

    /// Bridge for `SentrySDK.stopProfiler()`.
    @objc public static func sdkStopProfiler() {
        SentrySDK.stopProfiler()
    }
    #endif

    // MARK: - Metrics API

    /// Bridge for count metrics from ObjC to Swift
    @objc public static func metricsCount(
        key: String,
        value: UInt,
        attributes: [String: SentryObjCAttributeContent]
    ) {
        SentrySDK.metrics.count(key: key, value: value, attributes: attributes.mapValues { $0.toSwift() })
    }

    /// Bridge for distribution metrics from ObjC to Swift
    @objc public static func metricsDistribution(
        key: String,
        value: Double,
        unit: String?,
        attributes: [String: SentryObjCAttributeContent]
    ) {
        let swiftUnit = unit.flatMap { SentryUnit(rawValue: $0) }
        SentrySDK.metrics.distribution(key: key, value: value, unit: swiftUnit, attributes: attributes.mapValues { $0.toSwift() })
    }

    /// Bridge for gauge metrics from ObjC to Swift
    @objc public static func metricsGauge(
        key: String,
        value: Double,
        unit: String?,
        attributes: [String: SentryObjCAttributeContent]
    ) {
        let swiftUnit = unit.flatMap { SentryUnit(rawValue: $0) }
        SentrySDK.metrics.gauge(key: key, value: value, unit: swiftUnit, attributes: attributes.mapValues { $0.toSwift() })
    }

    // MARK: - Logger API

    /// Bridge for logger access from ObjC to Swift
    @objc public static var logger: SentryLogger {
        return SentrySDK.logger
    }

    // MARK: - Feedback API

    #if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
    /// Bridge for `SentrySDK.feedback`.
    @objc public static var sdkFeedback: SentryFeedbackAPI {
        return SentrySDK.feedback
    }
    #endif

    // MARK: - Replay API

    // Replay is conditionally available; not part of the SentryObjCBridging protocol
    // (which can't easily express the same conditional in pure ObjC). SentryObjC's
    // .m files declare it as an additional method on the bridge interface.
    #if SENTRY_TARGET_REPLAY_SUPPORTED
    /// Bridge for replay API access from ObjC to Swift
    @objc public static var replay: SentryReplayApi {
        return SentrySDK.replay
    }
    #endif
}

// MARK: - SentryObjCBridging conformance (Xcode framework builds only)
//
// In the Xcode framework build, the `Sentry` framework module's umbrella
// exposes its ObjC types under their original names — so the protocol's
// `@class SentryUser` (in SentryObjCTypes) and the bridge's `User` (NS_SWIFT_NAME
// alias) resolve to the same Swift type, and conformance verifies.
//
// In SPM, `import SentrySwift` only exposes the NS_SWIFT_NAME-aliased names
// (`User`, `Event`, …); the protocol's forward-decl placeholder types
// (`SentryUser`, `SentryEvent`) are different Swift identities than the
// bridge's parameter types, so the same conformance fails to compile.
//
// Splitting the conformance into a `#if !SWIFT_PACKAGE` extension keeps the
// drift-detection benefit on the canonical build path (Xcode → released
// xcframeworks) without breaking SPM compile-from-source. ObjC consumers see
// `SentryObjCBridge` as conforming to the protocol regardless (via the
// `@interface SentryObjCBridge : NSObject <SentryObjCBridging>` declaration in
// SentryObjC's `.m` files), and at link time the Swift bridge's `@objc`
// selectors match the protocol's declarations either way.
#if !SWIFT_PACKAGE
extension SentrySwiftBridge: SentryObjCBridging {}
#endif

// MARK: - ObjC → Swift mapping

private extension SentryObjCAttributeContent {
    /// Convert the public ObjC data carrier into the internal Swift enum.
    func toSwift() -> SentryAttributeContent {
        switch type {
        case .string:       return .string(stringValue ?? "")
        case .boolean:      return .boolean(booleanValue)
        case .integer:      return .integer(integerValue)
        case .double:       return .double(doubleValue)
        case .stringArray:  return .stringArray(stringArrayValue ?? [])
        case .booleanArray: return .booleanArray((booleanArrayValue ?? []).map(\.boolValue))
        case .integerArray: return .integerArray((integerArrayValue ?? []).map(\.intValue))
        case .doubleArray:  return .doubleArray((doubleArrayValue ?? []).map(\.doubleValue))
        @unknown default:   return .string("")
        }
    }
}
