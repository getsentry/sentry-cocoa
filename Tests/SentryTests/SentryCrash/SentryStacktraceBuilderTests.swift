@testable import Sentry
import SentryTestUtils
import XCTest

class SentryStacktraceBuilderTests: XCTestCase {
    
    private class Fixture {
        let queue = DispatchQueue(label: "SentryStacktraceBuilderTests")

        var sut: SentryStacktraceBuilder {
            SentryDependencyContainer.sharedInstance().reachability = TestSentryReachability()
            let res = SentryStacktraceBuilder(crashStackEntryMapper: SentryCrashStackEntryMapper(inAppLogic: SentryInAppLogic(inAppIncludes: [], inAppExcludes: [])))
            res.symbolicate = true
            return res
        }
    }

    private var fixture: Fixture!
    
    override class func setUp() {
        super.setUp()
        clearTestState()
    }

    override func setUp() {
        super.setUp()
        fixture = Fixture()
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

    func testConcurrentStacktraces() throws {
        guard #available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *) else {
            throw XCTSkip("Not available for earlier platform versions")
        }

        SentrySDK.start { options in
            options.dsn = TestConstants.dsnAsString(username: "SentryStacktraceBuilderTests")
            options.swiftAsyncStacktraces = true
            options.debug = true
        }

        let waitForAsyncToRun = expectation(description: "Wait async functions")
        Task {
            print("\(Date()) [Sentry] [TEST] running async task...")
            let filteredFrames = await self.firstFrame()
            waitForAsyncToRun.fulfill()
            XCTAssertGreaterThanOrEqual(filteredFrames, 3, "The Stacktrace must include the async callers.")
        }
        
        var timeout: TimeInterval = 1
        #if !os(watchOS) && !os(tvOS)
        // observed the async task taking a long time to finish if TSAN is attached
        if threadSanitizerIsPresent() {
            timeout = 10
        }
        #endif // !os(watchOS) || !os(tvOS)
        wait(for: [waitForAsyncToRun], timeout: timeout)
    }

    func testConcurrentStacktraces_noStitching() throws {
        guard #available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *) else {
            throw XCTSkip("Not available for earlier platform versions")
        }

        SentrySDK.start { options in
            options.dsn = TestConstants.dsnAsString(username: "SentryStacktraceBuilderTests")
            options.swiftAsyncStacktraces = false
            options.debug = true
        }

        let waitForAsyncToRun = expectation(description: "Wait async functions")
        Task {
            print("\(Date()) [Sentry] [TEST] running async task...")
            let filteredFrames = await self.firstFrame()
            waitForAsyncToRun.fulfill()
            XCTAssertGreaterThanOrEqual(filteredFrames, 1, "The Stacktrace must have only one function.")
        }
        
        var timeout: TimeInterval = 1
        #if !os(watchOS) && !os(tvOS)
        // observed the async task taking a long time to finish if TSAN is attached
        if threadSanitizerIsPresent() {
            timeout = 10
        }
        #endif // !os(watchOS) || !os(tvOS)
        wait(for: [waitForAsyncToRun], timeout: timeout)
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    func firstFrame() async -> Int {
        print("\(Date()) [Sentry] [TEST] first async frame about to await...")
        return await innerFrame1()
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    func innerFrame1() async -> Int {
        print("\(Date()) [Sentry] [TEST] second async frame about to await on task...")
        await Task { @MainActor in
            print("\(Date()) [Sentry] [TEST] executing task inside second async frame...")
        }.value
        return await innerFrame2()
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    func innerFrame2() async -> Int {
        let needed = ["firstFrame", "innerFrame1", "innerFrame2"]
        let actual = fixture.sut.buildStacktraceForCurrentThreadAsyncUnsafe()!
        let filteredFrames = actual.frames
            .compactMap({ $0.function })
            .filter { needed.contains(where: $0.contains) }
        print("\(Date()) [Sentry] [TEST] returning filtered frames.")
        return filteredFrames.count
    }
}
