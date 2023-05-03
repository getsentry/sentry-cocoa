@testable import Sentry
import SentryTestUtils
import XCTest

class SentryStacktraceBuilderTests: XCTestCase {
    
    private class Fixture {
        let queue = DispatchQueue(label: "SentryStacktraceBuilderTests")

        var sut: SentryStacktraceBuilder {
            return SentryStacktraceBuilder(crashStackEntryMapper: SentryCrashStackEntryMapper(inAppLogic: SentryInAppLogic(inAppIncludes: [], inAppExcludes: [])))
        }
    }

    private var fixture: Fixture!

    override func setUp() {
        super.setUp()
        fixture = Fixture()
        clearTestState()
    }

    override func tearDown() {
        super.tearDown()
        clearTestState()
    }
    
    func testEnoughFrames() {
        let actual = fixture.sut.buildStacktraceForCurrentThread()
        
        // The stacktrace has usually more than 40 frames. Feel free to change the number if the tests are failing
        XCTAssertTrue(30 < actual.frames.count, "Not enough stacktrace frames. It should be more than 30, but was \(actual.frames.count)")
    }
    
    func testFramesAreFilled() {
        let actual = fixture.sut.buildStacktraceForCurrentThread()
        
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
        let actual = fixture.sut.buildStacktraceForCurrentThread()
        
        let result = actual.frames.contains { frame in
            return frame.function?.contains("buildStacktraceForCurrentThread") ?? false
        }
        
        XCTAssertFalse(result, "The stacktrace should not contain the function that builds the stacktrace")
    }
    
    func testFramesOrder() {
        let actual = fixture.sut.buildStacktraceForCurrentThread()
        
        // Make sure the first 4 frames contain main
        let frames = actual.frames[...3]
        let filteredFrames = frames.filter { frame in
            return frame.function?.contains("main") ?? false
        }
        
        XCTAssertTrue(filteredFrames.count == 1, "The frames must be ordered from caller to callee, or oldest to youngest.")
    }
     
    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    func testConcurrentStacktraces() async throws {
        SentrySDK.start { options in
            options.dsn = TestConstants.dsnAsString(username: "SentryStacktraceBuilderTests")
        }

        await Task { await innerFrame1() }.value
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    func innerFrame1() async {
        await Task { @MainActor in }.value
        await innerFrame2()
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    func innerFrame2() async {
        let needed = ["testConcurrentStacktraces", "innerFrame1", "innerFrame2"]
        let actual = fixture.sut.buildStacktraceForCurrentThreadAsyncUnsafe()!
        let filteredFrames = actual.frames
            .compactMap(\.function)
            .filter { needed.contains(where: $0.contains) }
        XCTAssertGreaterThanOrEqual(filteredFrames.count, 3, "The Stacktrace must include the async callers.")
    }

    func asyncFrame1(expect: XCTestExpectation) {
        fixture.queue.asyncAfter(deadline: DispatchTime.now()) {
            self.asyncFrame2(expect: expect)
        }
    }
    
    func asyncFrame2(expect: XCTestExpectation) {
        fixture.queue.async {
            self.asyncAssertion(expect: expect)
        }
    }
    
    func asyncAssertion(expect: XCTestExpectation) {
        let actual = fixture.sut.buildStacktraceForCurrentThread()

        let filteredFrames = actual.frames.filter { frame in
            return frame.function?.contains("testAsyncStacktraces") ?? false ||
            frame.function?.contains("asyncFrame1") ?? false ||
            frame.function?.contains("asyncFrame2") ?? false
        }
        let startFrames = actual.frames.filter { frame in
            return frame.stackStart?.boolValue ?? false
        }

        XCTAssertTrue(filteredFrames.count >= 3, "The Stacktrace must include the async callers.")
        XCTAssertTrue(startFrames.count >= 3, "The Stacktrace must have async continuation markers.")

        expect.fulfill()
    }
}
