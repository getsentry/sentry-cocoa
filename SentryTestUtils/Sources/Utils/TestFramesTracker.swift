#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif

#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
@_spi(Private) public class TestFramesTracker: SentryFramesTracker {
    @_spi(Private) public var expectedFrames: SentryScreenFrames?
    
    @_spi(Private) public override func currentFrames() -> SentryScreenFrames {
        expectedFrames ?? super.currentFrames()
    }
}
#endif // (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
