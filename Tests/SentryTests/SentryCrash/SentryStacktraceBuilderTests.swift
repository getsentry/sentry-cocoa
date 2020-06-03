@testable import Sentry
import XCTest

class SentryStacktraceBuilderTests: XCTestCase {
    
    private class Fixture {
        func getSut() -> SentryStacktraceBuilder {
            SentryStacktraceBuilder()
        }
    }
    
    private let fixture = Fixture()
    
    func testExample() {
        let actual = fixture.getSut().buildStacktraceForCurrentThread()
        
        XCTAssertTrue(30 < actual.frames.count, "Not enough stacktrace frames.")
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
        
        let lastFrame = actual.frames.last
        
        let areFramesOrderedCorrect = lastFrame?.function?.contains("testFramesOrder") ?? false
        
        XCTAssertTrue(areFramesOrderedCorrect, "The frames must be ordered from caller to callee, or oldest to youngest.")
    }
}
