@_spi(Private) @testable import Sentry

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
