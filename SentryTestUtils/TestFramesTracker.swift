@_spi(Private) @testable import Sentry

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
public class TestFramesTracker: SentryFramesTracker {
    @_spi(Private) public var expectedFrames: SentryScreenFrames?
    
    @_spi(Private) public override func currentFrames() -> SentryScreenFrames {
        expectedFrames ?? super.currentFrames()
    }
}
#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
