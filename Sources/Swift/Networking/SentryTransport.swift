import Foundation

/// The result of flushing a transport's buffered envelopes.
@objc(SentryFlushResult) @_spi(Private)
public enum SentryFlushResult: Int {
    case success = 0
    case timedOut
    case alreadyFlushing
}

/// Sends envelopes to Sentry (or a Spotlight sidecar) and tracks lost events.
///
/// Named `SentryTransport` in Objective-C for backwards compatibility. `recordLostEvent` takes the
/// category and reason as `UInt` (the raw values of the ObjC `SentryDataCategory` /
/// `SentryDiscardReason` enums), mirroring `RateLimits`. Those enums have 200+ ObjC call sites and
/// are out of scope to convert, and they cannot appear in this SPI-public protocol because they are
/// only reachable via the implementation-only `_SentryPrivate` module. ObjC conformers therefore
/// declare these methods with `NSUInteger` params (which is selector-compatible) and cast to the
/// enum internally.
@objc(SentryTransport) @_spi(Private)
public protocol Transport: NSObjectProtocol {

    @objc(sendEnvelope:)
    func send(envelope: SentryEnvelope)

    @objc(storeEnvelope:)
    func store(_ envelope: SentryEnvelope)

    @objc(recordLostEvent:reason:)
    func recordLostEvent(_ category: UInt, reason: UInt)

    @objc(recordLostEvent:reason:quantity:)
    func recordLostEvent(_ category: UInt, reason: UInt, quantity: UInt)

    @objc(flush:)
    func flush(_ timeout: TimeInterval) -> SentryFlushResult

    #if DEBUG || SENTRY_TEST || SENTRY_TEST_CI
    @objc(setStartFlushCallback:)
    func setStartFlushCallback(_ callback: @escaping () -> Void)
    #endif // DEBUG || SENTRY_TEST || SENTRY_TEST_CI
}
