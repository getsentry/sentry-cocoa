// swiftlint:disable missing_docs
import Foundation

@_spi(Private)
@objc(SentryFlushResult)
public enum SentryFlushResult: Int {
    case success = 0
    case timedOut
    case alreadyFlushing
}

@_spi(Private)
@objc(SentryTransport)
public protocol Transport: NSObjectProtocol {

    @objc(sendEnvelope:)
    func send(envelope: SentryEnvelope)

    @objc(storeEnvelope:)
    func store(_ envelope: SentryEnvelope)

    @objc(recordLostEvent:reason:)
    func recordLostEvent(_ category: SentryDataCategory, reason: SentryDiscardReason)

    @objc(recordLostEvent:reason:quantity:)
    func recordLostEvent(_ category: SentryDataCategory, reason: SentryDiscardReason, quantity: UInt)

    @objc(flush:)
    func flush(_ timeout: TimeInterval) -> SentryFlushResult

    #if DEBUG || SENTRY_TEST || SENTRY_TEST_CI
    @objc(setStartFlushCallback:)
    func setStartFlushCallback(_ callback: @escaping () -> Void)
    #endif // DEBUG || SENTRY_TEST || SENTRY_TEST_CI
}
// swiftlint:enable missing_docs
