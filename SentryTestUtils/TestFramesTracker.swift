import Sentry

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
public class TestFramesTracker: SentryFramesTracker {
    public var expectedFrames: SentryScreenFrames?
    
    public override func currentFrames() -> SentryScreenFrames {
        expectedFrames ?? super.currentFrames()
    }
}
#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
