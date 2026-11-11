#if SWIFT_PACKAGE && !SDK_V10
@_spi(Private) import SentrySwift
#else
@_spi(Private) import Sentry
#endif
import SentryTestUtilsObjC

// Keep the SDK's names and nonthrowing signatures. Explicitly erased arguments select the
// original ObjC methods rather than recursively calling these typed overloads.
extension EnvelopeRateLimit {
    @_spi(Private) public func removeRateLimitedItems(_ envelope: SentryEnvelope) -> SentryEnvelope {
        requireTestBridgeValue(removeRateLimitedItems(envelope as Any))
    }
}
