// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
@_spi(Private) internal import SentrySwift
#else
@_spi(Private) internal import Sentry
#endif
import Foundation

@objc(SentryObjCInternalEnvelopeApi) public final class SentryObjCInternalEnvelopeApi: NSObject {
    internal let wrapped: SentryInternalEnvelopeApi

    internal init(_ wrapped: SentryInternalEnvelopeApi) {
        self.wrapped = wrapped
    }

    @objc public func store(_ envelope: SentryObjCEnvelope) {
        wrapped.store(envelope.wrapped)
    }

    @objc public func capture(_ envelope: SentryObjCEnvelope) {
        wrapped.capture(envelope.wrapped)
    }

    @objc public func deserializeFrom(_ data: Data) -> SentryObjCEnvelope? {
        guard let envelope = wrapped.deserialize(from: data) else { return nil }
        return SentryObjCEnvelope(envelope)
    }
}
// swiftlint:enable missing_docs
