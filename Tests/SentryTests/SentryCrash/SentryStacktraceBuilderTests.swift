@testable import Sentry
import XCTest

class SentryStacktraceBuilderTests: XCTestCase {
    
    private class Fixture {
        func getSut() -> SentryStacktraceBuilder {
            SentryStacktraceBuilder(crashStackEntryMapper: SentryCrashStackEntryMapper(frameInAppLogic: SentryFrameInAppLogic(inAppIncludes: [], inAppExcludes: [])))
        }
    }
    
    private let fixture = Fixture()
    
    func testEnoughFrames() {
        let actual = fixture.getSut().buildStacktraceForCurrentThread()
        
        // The stacktrace has usually more than 40 frames. Feel free to change the number if the tests are failing
        XCTAssertTrue(30 < actual.frames.count, "Not enough stacktrace frames.")
    }
    
    func testFramesAreFilled() {
        let actual = fixture.getSut().buildStacktraceForCurrentThread()
        
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
        let actual = fixture.getSut().buildStacktraceForCurrentThread()
        
        let result = actual.frames.contains { frame in
            return frame.function?.contains("buildStacktraceForCurrentThread") ?? false
        }
        
        XCTAssertFalse(result, "The stacktrace should not contain the function that builds the stacktrace")
    }
    
    func testFramesOrder() {
        let actual = fixture.getSut().buildStacktraceForCurrentThread()
        
        // Make sure the first 4 frames contain both start and main
        let frames = actual.frames[...3]
        let filteredFrames = frames.filter { frame in
            return frame.function?.contains("start") ?? false || frame.function?.contains("main") ?? false
        }
        
        XCTAssertTrue(filteredFrames.count == 2, "The frames must be ordered from caller to callee, or oldest to youngest.")
    }
}
