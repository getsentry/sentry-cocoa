import Sentry

public class TestFramesTracker: SentryFramesTracker {
    public var expectedFrames: SentryScreenFrames?
    
    public override func currentFrames() -> SentryScreenFrames {
        expectedFrames ?? super.currentFrames()
    }
}
