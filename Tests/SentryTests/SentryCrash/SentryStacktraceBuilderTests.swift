@testable import Sentry
import XCTest

class SentryStacktraceBuilderTests: XCTestCase {
    
    private class Fixture {
        func getSut() -> SentryStacktraceBuilder {
            SentryStacktraceBuilder(crashStackEntryMapper: SentryCrashStackEntryMapper(inAppLogic: SentryInAppLogic(inAppIncludes: [], inAppExcludes: [])))
        }
    }
    
    override func tearDown() {
        super.tearDown()
        SentrySDK.close()
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
    
    func testAsyncStacktraces() throws {
        SentrySDK.start(options: ["dsn": TestConstants.dsnAsString(username: "SentrySDKTests")])
        
        let group = DispatchGroup()

        DispatchQueue.main.async {
            group.enter()
            self.asyncFrame1(group: group)
        }
        
        group.waitWithTimeout()
    }
    
    func asyncFrame1(group: DispatchGroup) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now()) {
            self.asyncFrame2(group: group)
        }
    }
    
    func asyncFrame2(group: DispatchGroup) {
        DispatchQueue.main.async {
            self.asyncAssertion(group: group)
        }
    }
    
    func asyncAssertion(group: DispatchGroup) {
        let actual = self.fixture.getSut().buildStacktraceForCurrentThread()

        let filteredFrames = actual.frames.filter { frame in
            return frame.function?.contains("testAsyncStacktraces") ?? false ||
                frame.function?.contains("asyncFrame1") ?? false ||
                frame.function?.contains("asyncFrame2") ?? false ||
                frame.function?.contains("asyncAssertion") ?? false
        }
        let startFrames = actual.frames.filter { frame in
            return frame.stackStart?.boolValue ?? false
        }

        XCTAssertTrue(filteredFrames.count >= 4, "The Stacktrace must include the async callers.")
        XCTAssertTrue(startFrames.count >= 3, "The Stacktrace must have async continuation markers.")

        group.leave()
    }
}
