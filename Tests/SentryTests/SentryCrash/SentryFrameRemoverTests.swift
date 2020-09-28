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
        
        var nonSentryFrame: Frame {
            return frame(withPackage: "/private/var/containers/Bundle/Application/F42DD392-77D6-42B4-8092-D1AAE50C5B4B/iOS-Swift.app/iOS-Swift")
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
    }
    
    private let fixture = Fixture()
    private var sut: SentryFrameRemover!
    
    override func setUp() {
        sut = SentryFrameRemover()
    }
    
    func testSdkFramesFirst_OnlyFirstSentryFramesRemoved() {
        let frames = fixture.sentryFrames +
            fixture.nonSentryFrames +
            [fixture.sentryFrame] +
            [fixture.nonSentryFrame]
        
        let expected = fixture.nonSentryFrames +
            [fixture.sentryFrame] +
            [fixture.nonSentryFrame]
        let actual = sut.removeNonSdkFrames(frames)
        
        XCTAssertEqual(expected, actual)
    }
    
    func testNoSdkFramesFirst_NoFramesRemoved() {
        let frames = [fixture.nonSentryFrame] +
            [fixture.sentryFrame] +
            [fixture.nonSentryFrame]
        
        let actual = sut.removeNonSdkFrames(frames)
                XCTAssertEqual(frames, actual)
    }
    
    func testNoSdkFrames_NoFramesRemoved() {
        let actual = sut.removeNonSdkFrames(fixture.nonSentryFrames)
        XCTAssertEqual(fixture.nonSentryFrames, actual)
    }
    
    func testOnlySdkFrames_AllFramesRemoved() {
        let actual = sut.removeNonSdkFrames(fixture.sentryFrames)
        XCTAssertEqual(fixture.sentryFrames, actual)
    }
}
