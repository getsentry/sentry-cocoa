@testable import Sentry
import XCTest

class SentryStacktraceBuilderTests: XCTestCase {
    
    private class Fixture {
        func getSut() -> SentryStacktraceBuilder {
            SentryStacktraceBuilder()
        }
    }
    
    private let fixture = Fixture()
    
    func testEnoughFrames() {
        let actual = fixture.getSut().buildStacktraceForCurrentThread(framesToSkip: 0)
        
        // The stacktrace has usually more than 40 frames. Feel free to change the number if the tests are failing
        XCTAssertTrue(30 < actual.frames.count, "Not enough stacktrace frames.")
    }
    
    func testFramesAreFilled() {
        let actual = fixture.getSut().buildStacktraceForCurrentThread(framesToSkip: 0)
        
        // We don't know the actual values of the frames so we can't write
        // deterministic tests here. Therefore we just make sure they are
        // filled with some values.
        for frame in actual.frames {
            XCTAssertNotNil(frame.symbolAddress)
            XCTAssertNotNil(frame.function)
            XCTAssertNotNil(frame.imageAddress)
            XCTAssertNotNil(frame.instructionAddress)
        }
    }
    
    func testFramesDontContainBuilderFunction() {
        let actual = fixture.getSut().buildStacktraceForCurrentThread(framesToSkip: 0)
        
        let result = actual.frames.contains { frame in
            return frame.function?.contains("buildStacktraceForCurrentThread") ?? false
        }
        
        XCTAssertFalse(result, "The stacktrace should not contain the function that builds the stacktrace")
    }
    
    func testFramesOrder() {
        let actual = fixture.getSut().buildStacktraceForCurrentThread(framesToSkip: 0)
        let lastFrame = actual.frames.last
        let areFramesOrderedCorrect = lastFrame?.function?.contains("testFramesOrder") ?? false
        
        XCTAssertTrue(areFramesOrderedCorrect, "The frames must be ordered from caller to callee, or oldest to youngest.")
    }
    
    func testSkippingFrames() {
        // This function should be removed from the stacktrace
        func wrapperFunc() -> Stacktrace {
            fixture.getSut().buildStacktraceForCurrentThread(framesToSkip: 1)
        }
        let actual = wrapperFunc()
        let result = actual.frames.contains { frame in
            return frame.function?.contains("wrapperFunc") ?? false
        }
        
        XCTAssertFalse(result, "The stacktrace should not contain the wrapperFunc.")
        
         let noSkipping = fixture.getSut().buildStacktraceForCurrentThread(framesToSkip: 0)
        // The count must be equal because the stacktrace of actual has one more
        // function.
        XCTAssertEqual(noSkipping.frames.count, actual.frames.count)
    }
    
    func testSkippingAllFrames() {
        let actual = fixture.getSut().buildStacktraceForCurrentThread(framesToSkip: 1_000)
        
        XCTAssertEqual(0, actual.frames.count)
    }
}
