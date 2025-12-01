@_spi(Private) @testable import Sentry

#if !(os(iOS) || targetEnvironment(macCatalyst) || os(tvOS) || (swift(>=5.9) && os(visionOS)))
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
