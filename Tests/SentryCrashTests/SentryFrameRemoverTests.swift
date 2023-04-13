import XCTest

class SentryFrameRemoverTests: XCTestCase {
    
    private class Fixture {
        private func frame(withPackage package: String) -> Frame {
            let frame = Frame()
            frame.package = package
            return frame
        }
        
        var sentryFrame: Frame {
            return frame(withPackage: "/Users/sentry/private/var/containers/Bundle/Application/A722B503-2FA1-4C32-B5A7-E6FB47099C9D/iOS-Swift.app/Frameworks/Sentry.framework/Sentry")
        }

        var sentryPrivateFrame: Frame {
            return frame(withPackage: "/Users/sentry/private/var/containers/Bundle/Application/A722B503-2FA1-4C32-B5A7-E6FB47099C9D/iOS-Swift.app/Frameworks/SentryPrivate.framework/Sentry")
        }
        
        var nonSentryFrame: Frame {
            return frame(withPackage: "/Users/sentry/private/var/containers/Bundle/Application/F42DD392-77D6-42B4-8092-D1AAE50C5B4B/iOS-Swift.app/iOS-Swift")
        }

        var sentryFrames: [Frame] {
            var frames: [Frame] = []
            (0...3).forEach { _ in frames.append(sentryFrame) }
            (0...3).forEach { _ in frames.append(sentryPrivateFrame) }
            return frames
        }
        
        var nonSentryFrames: [Frame] {
            var frames: [Frame] = []
            (0...10).forEach { _ in frames.append(nonSentryFrame) }
            return frames
        }
    }
    
    private let fixture = Fixture()
    
    func testSdkFramesFirst_OnlyFirstSentryFramesRemoved() {
        let frames = fixture.sentryFrames +
            fixture.nonSentryFrames +
            [fixture.sentryFrame,
            fixture.sentryPrivateFrame,
            fixture.nonSentryFrame]
        
        let expected = fixture.nonSentryFrames +
            [fixture.sentryFrame,
             fixture.sentryPrivateFrame,
             fixture.nonSentryFrame]
        let actual = SentryFrameRemover.removeNonSdkFrames(frames)

        XCTAssert(equivalent(expected: expected, actual: actual))
    }
    
    func testNoSdkFramesFirst_NoFramesRemoved() {
        let frames = [fixture.nonSentryFrame] +
            [fixture.sentryFrame,
             fixture.sentryPrivateFrame,
             fixture.nonSentryFrame]
        
        let actual = SentryFrameRemover.removeNonSdkFrames(frames)
        XCTAssert(equivalent(expected: frames, actual: actual))
    }
    
    func testNoSdkFrames_NoFramesRemoved() {
        let actual = SentryFrameRemover.removeNonSdkFrames(fixture.nonSentryFrames)
        XCTAssert(equivalent(expected: fixture.nonSentryFrames, actual: actual))
    }
    
    func testOnlySdkFrames_AllFramesRemoved() {
        let actual = SentryFrameRemover.removeNonSdkFrames(fixture.sentryFrames)
        XCTAssert(equivalent(expected: fixture.sentryFrames, actual: actual))
    }
}

private extension SentryFrameRemoverTests {
    /// Compare elements pairwise to see if the two input arrays are equivalent or not.
    func equivalent(expected: [Frame], actual: [Frame]) -> Bool {
        guard expected.count == actual.count else { return false }
        for i in 0..<expected.count {
            let nextExpected = expected[i]
            let nextActual = actual[i]
            if nextExpected.package != nextActual.package {
                return false
            }
        }
        return true
    }
}
