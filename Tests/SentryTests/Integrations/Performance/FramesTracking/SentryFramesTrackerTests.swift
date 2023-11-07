import SentryTestUtils
import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class SentryFramesTrackerTests: XCTestCase {

    private class Fixture {

        var displayLinkWrapper: TestDisplayLinkWrapper
        var queue: DispatchQueue
        lazy var hub = TestHub(client: nil, andScope: nil)
        lazy var tracer = SentryTracer(transactionContext: TransactionContext(name: "test transaction", operation: "test operation"), hub: hub)

        init() {
            displayLinkWrapper = TestDisplayLinkWrapper()
            queue = DispatchQueue(label: "SentryFramesTrackerTests", qos: .background, attributes: [.concurrent])
        }

        lazy var sut: SentryFramesTracker = SentryFramesTracker(displayLinkWrapper: displayLinkWrapper)
    }

    private var fixture: Fixture!

    override func setUp() {
        super.setUp()
        fixture = Fixture()

#if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
        // the profiler must be running for the frames tracker to record frame rate info etc, validated in assertProfilingData()
        SentryProfiler.start(withTracer: fixture.tracer.traceId)
#endif
    }

    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

    func testIsNotRunning_WhenNotStarted() {
        XCTAssertFalse(fixture.sut.isRunning)
    }

    func testIsRunning_WhenStarted() {
        let sut = fixture.sut
        sut.start()
        XCTAssertTrue(sut.isRunning)
    }

    func testIsNotRunning_WhenStopped() {
        let sut = fixture.sut
        sut.start()
        sut.stop()
        XCTAssertFalse(sut.isRunning)
    }

    func testSlowFrame() throws {
        let sut = fixture.sut
        sut.start()

        fixture.displayLinkWrapper.call()
        _ = fixture.displayLinkWrapper.fastestSlowFrame()
        fixture.displayLinkWrapper.normalFrame()
        _ = fixture.displayLinkWrapper.slowestSlowFrame()

        try assert(slow: 2, frozen: 0, total: 3)
    }

    func testFrozenFrame() throws {
        let sut = fixture.sut
        sut.start()

        fixture.displayLinkWrapper.call()
        _ = fixture.displayLinkWrapper.fastestSlowFrame()
        _ = fixture.displayLinkWrapper.fastestFrozenFrame()

        try assert(slow: 1, frozen: 1, total: 2)
    }

    func testFrameRateChange() throws {
        let sut = fixture.sut
        sut.start()

        fixture.displayLinkWrapper.call()
        _ = fixture.displayLinkWrapper.fastestSlowFrame()
        fixture.displayLinkWrapper.changeFrameRate(.high)
        _ = fixture.displayLinkWrapper.fastestFrozenFrame()

        try assert(slow: 1, frozen: 1, total: 2, frameRates: 2)
    }

    func testPerformanceOfTrackingFrames() throws {
        let sut = fixture.sut
        sut.start()

        let frames: UInt = 1_000
        self.measure {
            for _ in 0 ..< frames {
                fixture.displayLinkWrapper.normalFrame()
            }
        }

        try assert(slow: 0, frozen: 0)
    }

    func testAddListener() {
        let sut = fixture.sut
        let listener = FrameTrackerListener()
        sut.start()
        sut.add(listener)

        fixture.displayLinkWrapper.normalFrame()

        XCTAssertTrue(listener.newFrameReported)
    }

    func testRemoveListener() {
        let sut = fixture.sut
        let listener = FrameTrackerListener()
        sut.start()
        sut.add(listener)
        sut.remove(listener)

        fixture.displayLinkWrapper.normalFrame()

        XCTAssertFalse(listener.newFrameReported)
    }

    func testReleasedListener() {
        let sut = fixture.sut
        var callbackCalls = 0
        sut.start()

        autoreleasepool {
            let listener = FrameTrackerListener()
            listener.callback = {
                callbackCalls += 1
            }
            sut.add(listener)
            fixture.displayLinkWrapper.normalFrame()
        }

        fixture.displayLinkWrapper.normalFrame()

        XCTAssertEqual(callbackCalls, 1)
    }
}

private class FrameTrackerListener: NSObject, SentryFramesTrackerListener {
    var newFrameReported = false
    var callback: (() -> Void)?
    func framesTrackerHasNewFrame() {
        newFrameReported = true
        callback?()
    }
}

private extension SentryFramesTrackerTests {
    func assert(slow: UInt? = nil, frozen: UInt? = nil, total: UInt? = nil, frameRates: UInt? = nil) throws {
        let currentFrames = fixture.sut.currentFrames
        if let total = total {
            XCTAssertEqual(total, currentFrames.total)
        }
        if let slow = slow {
            XCTAssertEqual(slow, currentFrames.slow)
        }
        if let frozen = frozen {
            XCTAssertEqual(frozen, currentFrames.frozen)
        }

#if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
        try  assertProfilingData(slow: slow, frozen: frozen, frameRates: frameRates)
#endif
    }

#if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
    func assertProfilingData(slow: UInt? = nil, frozen: UInt? = nil, frameRates: UInt? = nil) throws {
        if threadSanitizerIsPresent() {
            // profiling data will not have been gathered with TSAN running
            return
        }
        
        func assertFrameInfo(frame: [String: NSNumber]) throws {
            XCTAssertNotNil(frame["timestamp"], "Expected a timestamp for the frame.")
            XCTAssertNotNil(frame["value"], "Expected a duration value for the frame.")
        }

        let currentFrames = fixture.sut.currentFrames

        if let slow = slow {
            XCTAssertEqual(currentFrames.slowFrameTimestamps.count, Int(slow))
            for frame in currentFrames.slowFrameTimestamps {
                try assertFrameInfo(frame: frame)
            }
        }
        if let frozen = frozen {
            XCTAssertEqual(currentFrames.frozenFrameTimestamps.count, Int(frozen))
            for frame in currentFrames.frozenFrameTimestamps {
                try assertFrameInfo(frame: frame)
            }
        }
        if let frameRates = frameRates {
            XCTAssertEqual(currentFrames.frameRateTimestamps.count, Int(frameRates))
        }
    }
#endif
}

#endif
