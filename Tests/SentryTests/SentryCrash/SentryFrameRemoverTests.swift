import XCTest

class SentryFrameRemoverTests: XCTestCase {
    
    private class Fixture {
        private func frame(withPackage package: String) -> Frame {
            let frame = Frame()
            frame.package = package
            return frame
        }
        
        var sentryFrame: Frame {
            return frame(withPackage: "/private/var/containers/Bundle/Application/A722B503-2FA1-4C32-B5A7-E6FB47099C9D/iOS-Swift.app/Frameworks/Sentry.framework/Sentry")
        }
        
        var sentryUserSentryFrame: Frame {
            return frame(withPackage: "/Users/sentry/var/containers/Bundle/Application/F42DD392-77D6-42B4-8092-D1AAE50C5B4B/iOS-Swift.app/Sentry.framework/Sentry")
        }
        
        var nonSentryFrame: Frame {
            return frame(withPackage: "/private/var/containers/Bundle/Application/F42DD392-77D6-42B4-8092-D1AAE50C5B4B/iOS-Swift.app/iOS-Swift")
        }
        
        var sentryUserNonSentryFrame: Frame {
            return frame(withPackage: "/Users/sentry/var/containers/Bundle/Application/F42DD392-77D6-42B4-8092-D1AAE50C5B4B/iOS-Swift.app/iOS-Swift")
        }
        
        var sentryFrames: [Frame] {
            var frames: [Frame] = []
            (0...7).forEach { _ in frames.append(sentryFrame) }
            return frames
        }
        
        var nonSentryFrames: [Frame] {
            var frames: [Frame] = []
            (0...10).forEach { _ in frames.append(nonSentryFrame) }
            return frames
        }
        
        var sentryUserNonSentryFrames: [Frame] {
            var frames: [Frame] = []
            (0...10).forEach { _ in frames.append(sentryUserNonSentryFrame) }
            return frames
        }
        
        var sentryUserSentryFrames: [Frame] {
            var frames: [Frame] = []
            (0...10).forEach { _ in frames.append(sentryUserSentryFrame) }
            return frames
        }
    }
    
    private let fixture = Fixture()
    
    func testSdkFramesFirst_OnlyFirstSentryFramesRemoved() {
        let frames = fixture.sentryFrames +
            fixture.sentryUserSentryFrames +
            fixture.nonSentryFrames +
            [fixture.sentryFrame] +
            [fixture.sentryUserSentryFrame] +
            [fixture.nonSentryFrame]
        
        let expected = fixture.nonSentryFrames +
            [fixture.sentryFrame] +
            [fixture.sentryUserSentryFrame] +
            [fixture.nonSentryFrame]
        let actual = SentryFrameRemover.removeNonSdkFrames(frames)
        
        XCTAssertEqual(expected, actual)
    }
    
    func testNoSdkFramesFirst_NoFramesRemoved() {
        let frames = [fixture.nonSentryFrame] +
            [fixture.sentryUserNonSentryFrame] +
            [fixture.sentryFrame] +
            [fixture.nonSentryFrame]
        
        let actual = SentryFrameRemover.removeNonSdkFrames(frames)
                XCTAssertEqual(frames, actual)
    }
    
    func testNoSdkFrames_NoFramesRemoved() {
        let actual1 = SentryFrameRemover.removeNonSdkFrames(fixture.nonSentryFrames)
        XCTAssertEqual(fixture.nonSentryFrames, actual1)
        
        let actual2 = SentryFrameRemover.removeNonSdkFrames(fixture.sentryUserNonSentryFrames)
        XCTAssertEqual(fixture.sentryUserNonSentryFrames, actual2)
    }
    
    func testOnlySdkFrames_AllFramesRemoved() {
        let actual1 = SentryFrameRemover.removeNonSdkFrames(fixture.sentryFrames)
        XCTAssertEqual(fixture.sentryFrames, actual1)
        
        let actual2 = SentryFrameRemover.removeNonSdkFrames(fixture.sentryUserSentryFrames)
        XCTAssertEqual(fixture.sentryUserSentryFrames, actual2)
    }
}
