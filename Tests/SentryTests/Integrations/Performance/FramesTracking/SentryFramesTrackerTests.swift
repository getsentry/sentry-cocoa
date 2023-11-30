import Nimble
import SentryTestUtils
import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class SentryFramesTrackerTests: XCTestCase {

    private class Fixture {

        var displayLinkWrapper: TestDisplayLinkWrapper
        var queue: DispatchQueue
        var dateProvider = TestCurrentDateProvider()
        lazy var hub = TestHub(client: nil, andScope: nil)
        lazy var tracer = SentryTracer(transactionContext: TransactionContext(name: "test transaction", operation: "test operation"), hub: hub)

        init() {
            displayLinkWrapper = TestDisplayLinkWrapper(dateProvider: dateProvider)
            queue = DispatchQueue(label: "SentryFramesTrackerTests", qos: .background, attributes: [.concurrent])
        }

        lazy var sut: SentryFramesTracker = SentryFramesTracker(displayLinkWrapper: displayLinkWrapper, dateProvider: dateProvider)
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
        expect(self.fixture.sut.isRunning) == false
    }

    func testIsRunning_WhenStarted() {
        let sut = fixture.sut
        sut.start()
        expect(self.fixture.sut.isRunning) == true
    }
    
    func testStartTwice_SubscribesOnceToDisplayLink() {
        let sut = fixture.sut
        sut.start()
        sut.start()
        
        expect(self.fixture.displayLinkWrapper.linkInvocations.count) == 1
    }

    func testIsNotRunning_WhenStopped() {
        let sut = fixture.sut
        sut.start()
        sut.stop()
        
        expect(self.fixture.sut.isRunning) == false
    }
    
    func testStartAfterStopped_SubscribesTwiceToDisplayLink() {
        let sut = fixture.sut
        sut.start()
        sut.stop()
        sut.start()
        
        expect(sut.isRunning) == true
        expect(self.fixture.displayLinkWrapper.linkInvocations.count) == 2
    }

    func testSlowFrame() throws {
        let sut = fixture.sut
        sut.start()
        
        let displayLink = fixture.displayLinkWrapper
        displayLink.call()
        _ = displayLink.fastestSlowFrame()
        displayLink.normalFrame()
        _ = displayLink.slowestSlowFrame()
        
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
    
    /**
     * The following test validates one slow and one frozen frame in the time interval. The slow frame starts at
     * the beginning of the time interval and the frozen frame stops at the end of the time interval.
     *
     * [nf][- sf - ][nf][ ---- ff ---- ]     |  nf = normal frame, sf = slow frame,  ff = frozen frame
     * [---------  time interval -------]
     */
    func testFrameDelay_SlowAndFrozenFrameWithinTimeInterval() {
        let sut = fixture.sut
        sut.start()

        let startDate = fixture.dateProvider.systemTime()
        
        let displayLink = fixture.displayLinkWrapper
        displayLink.call()
        displayLink.normalFrame()
        _ = displayLink.fastestSlowFrame()
        displayLink.normalFrame()
        _ = displayLink.slowestSlowFrame()
        
        let endDate = fixture.dateProvider.systemTime()
        
        let expectedDelay = displayLink.timeEpsilon + displayLink.frozenFrameThreshold - slowFrameThreshold(displayLink.currentFrameRate.rawValue)
        
        let actualFrameDelay = sut.getFrameDelay(startDate, endSystemTimestamp: endDate)
        expect(actualFrameDelay).to(beCloseTo(expectedDelay, within: 0.0001))
    }
    
    /**
     * The following test validates one delayed frame starting before time interval and ending with the time interval.
     *
     * [----  delayed frame ---- ]
     *      [- time interval -- ]
     */
    func testDelayedFrameStartsBeforeTimeInterval() {
        let timeIntervalAfterFrameStart = 0.5
        
        // The slow frame threshold is not included because the delayed frame started before the startDate and the rendering on time happened before the startDate.
        let expectedDelay = fixture.displayLinkWrapper.frozenFrameThreshold - timeIntervalAfterFrameStart
        
        testFrameDelay(timeIntervalAfterFrameStart: timeIntervalAfterFrameStart, expectedDelay: expectedDelay)
    }
    
    /**
     * The following test validates one delayed frame starting shortly before time interval and ending with the time interval.
     * Parts of the expected frame duration overlap with the beginning of the time interval, and are therefore not added to
     * the frame delay.
     *
     * [| e |  delayed frame ---- ]      e = the expected frame duration
     *   [---- time interval ---- ]
     */
    func testDelayedFrameStartsShortlyBeforeTimeInterval_OnlyDelayedPartAdded() {
        let timeIntervalAfterFrameStart = 0.0001
        
        // The timeIntervalAfterFrameStart is not subtracted from the delay, because that's when the frame was expected to be rendered on time.
        let expectedDelay = fixture.displayLinkWrapper.frozenFrameThreshold - slowFrameThreshold(fixture.displayLinkWrapper.currentFrameRate.rawValue)
        
        testFrameDelay(timeIntervalAfterFrameStart: timeIntervalAfterFrameStart, expectedDelay: expectedDelay)
    }
    
    /**
     * The following test validates one delayed frame starting shortly before time interval and ending after the time interval.
     * Parts of the expected frame duration overlap with the beginning of the time interval, and are therefore not added to
     * the frame delay.
     *
     * [| e |  delayed frame ------ ]      e = the expected frame duration
     *   [---- time interval ---- ]
     */
    func testDelayedFrameStartsAndEndsBeforeTimeInterval_OnlyDelayedPartAdded() {
        let displayLink = fixture.displayLinkWrapper
        
        let timeIntervalAfterFrameStart = 0.1
        let timeIntervalBeforeFrameEnd = 0.01
        
        // The slow frame threshold is not included because the startDate is after the frame rendered on time.
        let expectedDelay = displayLink.frozenFrameThreshold - timeIntervalAfterFrameStart - timeIntervalBeforeFrameEnd
        
        testFrameDelay(timeIntervalAfterFrameStart: timeIntervalAfterFrameStart, timeIntervalBeforeFrameEnd: timeIntervalBeforeFrameEnd, expectedDelay: expectedDelay)
    }
    
    /**
     * The following test validates two delayed frames. The delay of the first one is fully added to the frame delay.
     * No delay of the second frame is added because only the expected frame duration overlaps with the time interval.
     *
     * [| e |  delayed frame ] [| e |  delayed frame - ]  e = the expected frame duration
     * [------ time interval ----- ]
     */
    func testOneDelayedFrameStartsShortlyEndsBeforeTimeInterval() {
        let sut = fixture.sut
        sut.start()

        let startDate = fixture.dateProvider.systemTime()
        
        let displayLink = fixture.displayLinkWrapper
        displayLink.call()
        _ = displayLink.slowestSlowFrame()
        displayLink.normalFrame()
        _ = displayLink.fastestSlowFrame()
        
        let timeIntervalBeforeFrameEnd = slowFrameThreshold(displayLink.currentFrameRate.rawValue) - 0.005
        let endDate = fixture.dateProvider.systemTime() - timeIntervalToNanoseconds(timeIntervalBeforeFrameEnd)
        
        let expectedDelay = displayLink.frozenFrameThreshold - slowFrameThreshold(displayLink.currentFrameRate.rawValue)
        
        let actualFrameDelay = sut.getFrameDelay(startDate, endSystemTimestamp: endDate)
        expect(actualFrameDelay).to(beCloseTo(expectedDelay, within: 0.0001))
    }
    
    private func testFrameDelay(timeIntervalAfterFrameStart: TimeInterval = 0.0, timeIntervalBeforeFrameEnd: TimeInterval = 0.0, expectedDelay: TimeInterval) {
        let sut = fixture.sut
        sut.start()

        let slowFrameStartDate = fixture.dateProvider.systemTime()
        
        let displayLink = fixture.displayLinkWrapper
        displayLink.call()
        _ = displayLink.slowestSlowFrame()
        
        let endDate = fixture.dateProvider.systemTime() - timeIntervalToNanoseconds(timeIntervalBeforeFrameEnd)
        
        let startDate = slowFrameStartDate + timeIntervalToNanoseconds(timeIntervalAfterFrameStart)
        
        let actualFrameDelay = sut.getFrameDelay(startDate, endSystemTimestamp: endDate)
        expect(actualFrameDelay).to(beCloseTo(expectedDelay, within: 0.0001))
    }
    
    func testFrameDelay_WithStartBeforeEnd_Returns0() {
        let sut = fixture.sut
        sut.start()
        
        let displayLink = fixture.displayLinkWrapper
        displayLink.call()
        _ = displayLink.slowestSlowFrame()
        
        let actualFrameDelay = sut.getFrameDelay(1, endSystemTimestamp: 0)
        expect(actualFrameDelay).to(beCloseTo(0.0, within: 0.0001))
    }
    
    func testFrameDelay_LongestTimeStamp() {
        let sut = fixture.sut
        sut.start()
        
        let displayLink = fixture.displayLinkWrapper
        displayLink.call()
        _ = displayLink.slowestSlowFrame()
        
        let expectedDelay = displayLink.frozenFrameThreshold - slowFrameThreshold(displayLink.currentFrameRate.rawValue)

        let actualFrameDelay = sut.getFrameDelay(0, endSystemTimestamp: UInt64.max)
        expect(actualFrameDelay).to(beCloseTo(expectedDelay, within: 0.0001))
    }
    
    func testFrameDelay_TimeSpanBiggerThanRecordOfDelayedFrames_Return0() {
        let sut = fixture.sut
        sut.start()
        
        let capacity = 1_024
        
        let displayLink = fixture.displayLinkWrapper
        displayLink.call()
        
        for _ in 0..<(capacity * 2) {
            _ = displayLink.slowestSlowFrame()
        }

        // We don't know what the frame delay was as the timespan is bigger
        let actualFrameDelay = sut.getFrameDelay(0, endSystemTimestamp: UInt64.max)
        expect(actualFrameDelay) == -1.0
    }
    
    func testFrameDelay_KeepAddingSlowFrames_OnlyTheLast1024SlowFramesAreReturned() {
        let sut = fixture.sut
        sut.start()
        
        let capacity = 1_024
        
        let displayLink = fixture.displayLinkWrapper
        displayLink.call()
        
        for _ in 0..<(capacity * 2) {
            _ = displayLink.slowestSlowFrame()
        }
        
        let expectedDelay = (displayLink.frozenFrameThreshold - slowFrameThreshold(displayLink.currentFrameRate.rawValue)) * Double(capacity)

        let actualFrameDelay = sut.getFrameDelay(0, endSystemTimestamp: UInt64.max)
        expect(actualFrameDelay).to(beCloseTo(expectedDelay, within: 0.0001))
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
    
    func testDealloc_CallsStop() {
        
        func sutIsDeallocatedAfterCallingMe() {
            _ = SentryFramesTracker(displayLinkWrapper: fixture.displayLinkWrapper, dateProvider: fixture.dateProvider)
        }
        sutIsDeallocatedAfterCallingMe()
        
        XCTAssertEqual(1, fixture.displayLinkWrapper.invalidateInvocations.count)
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
