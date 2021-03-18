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
    
    func testAsyncStacktraces() {
        let expectation = XCTestExpectation(description: "async stack generated")

        DispatchQueue.main.async {
            // XXX: now this is a bit strange, starting the SDK / hooking async calls in
            // the context of the test function does not work correctly, however doing so
            // in this async callback does work as expected.
            SentrySDK.start(options: ["dsn": TestConstants.dsnAsString(username: "SentrySDKTests")])

            self.asyncFrame1(expectation: expectation)
        }

        wait(for: [expectation], timeout: 5)
    }
    
    func asyncFrame1(expectation: XCTestExpectation) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now()) {
            self.asyncFrame2(expectation: expectation)
        }
    }
    func asyncFrame2(expectation: XCTestExpectation) {
        DispatchQueue.main.async {
            self.asyncAssertion(expectation: expectation)
        }
    }
    func asyncAssertion(expectation: XCTestExpectation) {
        let actual = self.fixture.getSut().buildStacktraceForCurrentThread()

        let filteredFrames = actual.frames.filter { frame in
            return frame.function?.contains("testAsyncStacktraces") ?? false ||
                frame.function?.contains("asyncFrame1") ?? false ||
                frame.function?.contains("asyncFrame2") ?? false ||
                frame.function?.contains("asyncAssertion") ?? false
        }

        XCTAssertTrue(filteredFrames.count >= 4, "The Stacktrace must include the async callers.")

        expectation.fulfill()
    }
}
