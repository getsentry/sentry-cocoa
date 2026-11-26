#if SWIFT_PACKAGE && !SDK_V10
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif

#if !(os(iOS) || os(tvOS) || os(visionOS))
class TestSentryNSApplication: SentryApplication {
    private var _underlyingIsActive = true
    func setIsActive(_ isActive: Bool) {
        _underlyingIsActive = isActive
    }
    var mainThread_isActive: Bool {
        return _underlyingIsActive
    }
}
#endif
