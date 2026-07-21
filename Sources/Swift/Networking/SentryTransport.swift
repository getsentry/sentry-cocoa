import Foundation

/// The result of flushing a transport's buffered envelopes.
@_spi(Private)
@objc(SentryFlushResult)
public enum SentryFlushResult: Int {
    /// All buffered envelopes were flushed successfully.
    case success = 0
    /// Flushing did not complete before the requested timeout elapsed.
    case timedOut
    /// A flush was already in progress, so this request was ignored.
    case alreadyFlushing
}

/// Sends envelopes to Sentry (or a Spotlight sidecar) and tracks lost events.
///
/// Named `SentryTransport` in Objective-C for backwards compatibility via the `@objc(SentryTransport)` attribute.
@_spi(Private)
@objc(SentryTransport)
public protocol Transport: NSObjectProtocol {

    /// Sends an envelope to Sentry.
    @objc(sendEnvelope:)
    func send(envelope: SentryEnvelope)

    /// Stores an envelope on disk without sending it.
    @objc(storeEnvelope:)
    func store(_ envelope: SentryEnvelope)

    /// Records a single lost event for the given category and discard reason.
    @objc(recordLostEvent:reason:)
    func recordLostEvent(_ category: SentryDataCategory, reason: SentryDiscardReason)

    /// Records a number of lost events for the given category and discard reason.
    @objc(recordLostEvent:reason:quantity:)
    func recordLostEvent(_ category: SentryDataCategory, reason: SentryDiscardReason, quantity: UInt)

    /// Flushes buffered envelopes, waiting up to the given timeout.
    @objc(flush:)
    func flush(_ timeout: TimeInterval) -> SentryFlushResult

    #if DEBUG || SENTRY_TEST || SENTRY_TEST_CI
    /// Sets a callback invoked when a flush starts. Available in test builds only.
    @objc(setStartFlushCallback:)
    func setStartFlushCallback(_ callback: @escaping () -> Void)
    #endif // DEBUG || SENTRY_TEST || SENTRY_TEST_CI
}
