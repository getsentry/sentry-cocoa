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

    func testConcurrentStacktraces() {
        guard #available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *) else { return }

        SentrySDK.start { options in
            options.dsn = TestConstants.dsnAsString(username: "SentryStacktraceBuilderTests")
            options.stitchSwiftAsync = true
        }

        let waitForAsyncToRun = expectation(description: "Wait async functions")
        Task {
            let filteredFrames = await self.firstFrame()
            waitForAsyncToRun.fulfill()
            XCTAssertGreaterThanOrEqual(filteredFrames, 3, "The Stacktrace must include the async callers.")
        }
        wait(for: [waitForAsyncToRun], timeout: 1)
    }

    func testConcurrentStacktraces_noStitching() {
        guard #available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *) else { return }

        SentrySDK.start { options in
            options.dsn = TestConstants.dsnAsString(username: "SentryStacktraceBuilderTests")
            options.stitchSwiftAsync = false
        }

        let waitForAsyncToRun = expectation(description: "Wait async functions")
        Task {
            let filteredFrames = await self.firstFrame()
            waitForAsyncToRun.fulfill()
            XCTAssertGreaterThanOrEqual(filteredFrames, 1, "The Stacktrace must have only one function.")
        }
        wait(for: [waitForAsyncToRun], timeout: 1)
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    func firstFrame() async -> Int {
        return await innerFrame1()
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    func innerFrame1() async -> Int {
        await Task { @MainActor in }.value
        return await innerFrame2()
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    func innerFrame2() async -> Int {
        let needed = ["firstFrame", "innerFrame1", "innerFrame2"]
        let actual = fixture.sut.buildStacktraceForCurrentThreadAsyncUnsafe()!
        let filteredFrames = actual.frames
            .compactMap({ $0.function })
            .filter { needed.contains(where: $0.contains) }
        return filteredFrames.count

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
