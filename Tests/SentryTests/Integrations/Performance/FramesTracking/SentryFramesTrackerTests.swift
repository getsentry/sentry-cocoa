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

        let startSystemTime = fixture.dateProvider.systemTime()
        
        let displayLink = fixture.displayLinkWrapper
        displayLink.call()
        displayLink.normalFrame()
        _ = displayLink.fastestSlowFrame()
        displayLink.normalFrame()
        _ = displayLink.slowestSlowFrame()
        
        let endSystemTime = fixture.dateProvider.systemTime()
        
        let expectedDelay = displayLink.timeEpsilon + displayLink.frozenFrameThreshold - slowFrameThreshold(displayLink.currentFrameRate.rawValue)
        
        let actualFrameDelay = sut.getFrameDelay(startSystemTime, endSystemTimestamp: endSystemTime)
        expect(actualFrameDelay).to(beCloseTo(expectedDelay, within: 0.0001))
    }
    
    /**
     * When there is no frame information around yet, because the frame about to be drawn is still delayed,
     * the delay should be returned as such.
     *
     * [nf][ ------- ?? ------ ]   |  nf = normal frame,  ?? = No frame information
     * [----  time interval ----]
     */
    func testFrameDelay_NoFrameRenderedButShouldHave_DelayReturned() {
        let sut = fixture.sut
        sut.start()

        let startSystemTime = fixture.dateProvider.systemTime()
        
        let displayLink = fixture.displayLinkWrapper
        displayLink.call()
        displayLink.normalFrame()
        
        let delayWithoutFrameRecord = 1.0
        fixture.dateProvider.advance(by: delayWithoutFrameRecord)
        let endSystemTime = fixture.dateProvider.systemTime()
        
        let expectedDelay = delayWithoutFrameRecord - slowFrameThreshold(displayLink.currentFrameRate.rawValue)
        
        let actualFrameDelay = sut.getFrameDelay(startSystemTime, endSystemTimestamp: endSystemTime)
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
    
    private func testFrameDelay(timeIntervalAfterFrameStart: TimeInterval = 0.0, timeIntervalBeforeFrameEnd: TimeInterval = 0.0, expectedDelay: TimeInterval) {
        let sut = fixture.sut
        sut.start()

        let slowFrameStartSystemTime = fixture.dateProvider.systemTime()
        
        let displayLink = fixture.displayLinkWrapper
        displayLink.call()
        _ = displayLink.slowestSlowFrame()
        
        let endSystemTime = fixture.dateProvider.systemTime() - timeIntervalToNanoseconds(timeIntervalBeforeFrameEnd)
        
        let startSystemTime = slowFrameStartSystemTime + timeIntervalToNanoseconds(timeIntervalAfterFrameStart)
        
        let actualFrameDelay = sut.getFrameDelay(startSystemTime, endSystemTimestamp: endSystemTime)
        expect(actualFrameDelay).to(beCloseTo(expectedDelay, within: 0.0001))
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

        let startSystemTime = fixture.dateProvider.systemTime()
        
        let displayLink = fixture.displayLinkWrapper
        displayLink.call()
        _ = displayLink.slowestSlowFrame()
        displayLink.normalFrame()
        _ = displayLink.fastestSlowFrame()
        
        let timeIntervalBeforeFrameEnd = slowFrameThreshold(displayLink.currentFrameRate.rawValue) - 0.005
        let endSystemTime = fixture.dateProvider.systemTime() - timeIntervalToNanoseconds(timeIntervalBeforeFrameEnd)
        
        let expectedDelay = displayLink.frozenFrameThreshold - slowFrameThreshold(displayLink.currentFrameRate.rawValue)
        
        let actualFrameDelay = sut.getFrameDelay(startSystemTime, endSystemTimestamp: endSystemTime)
        expect(actualFrameDelay).to(beCloseTo(expectedDelay, within: 0.0001))
    }
    
    func testFrameDelay_WithStartBeforeEnd_ReturnsMinusOne() {
        let sut = fixture.sut
        sut.start()
        
        let displayLink = fixture.displayLinkWrapper
        displayLink.call()
        _ = displayLink.slowestSlowFrame()
        
        let actualFrameDelay = sut.getFrameDelay(1, endSystemTimestamp: 0)
        expect(actualFrameDelay) == -1.0
    }
    
    func testFrameDelay_LongestTimeStamp_ReturnsMinusOne() {
        let sut = fixture.sut
        sut.start()
        
        let displayLink = fixture.displayLinkWrapper
        displayLink.call()
        _ = displayLink.slowestSlowFrame()

        let actualFrameDelay = sut.getFrameDelay(0, endSystemTimestamp: UInt64.max)
        expect(actualFrameDelay) == -1.0
    }
    
    func testFrameDelay_KeepAddingSlowFrames_OnlyTheCapacityFramesReturned() {
        let displayLink = fixture.displayLinkWrapper
        let sut = fixture.sut
        sut.start()
        
        let startSystemTime = givenMoreDelayedFramesThanTransactionMaxDuration()
        
        let endSystemTime = fixture.dateProvider.systemTime()
        
        let expectedDelay = (displayLink.frozenFrameThreshold - slowFrameThreshold(displayLink.currentFrameRate.rawValue))

        let actualFrameDelay = sut.getFrameDelay(startSystemTime, endSystemTimestamp: endSystemTime)
        expect(actualFrameDelay).to(beCloseTo(expectedDelay, within: 0.0001))
    }
    
    func testFrameDelay_MoreThanTransactionMaxDuration_FrameInformationMissing_DelayReturned() {
        let sut = fixture.sut
        let displayLink = fixture.displayLinkWrapper
        sut.start()
        
        let startSystemTime = givenMoreDelayedFramesThanTransactionMaxDuration()
        
        let delayWithoutFrameRecord = 2.0
        fixture.dateProvider.advance(by: delayWithoutFrameRecord)
        let endSystemTime = fixture.dateProvider.systemTime()
        
        let slowFrames = sut.currentFrames.slow
        let slowestSlowFrameDelay = (displayLink.frozenFrameThreshold - slowFrameThreshold(displayLink.currentFrameRate.rawValue))
        
        let delayNotRecorded = delayWithoutFrameRecord - slowFrameThreshold(displayLink.currentFrameRate.rawValue)
        let expectedDelay = slowestSlowFrameDelay * Double(slowFrames) + delayNotRecorded

        let actualFrameDelay = sut.getFrameDelay(startSystemTime, endSystemTimestamp: endSystemTime)
        expect(actualFrameDelay).to(beCloseTo(expectedDelay, within: 0.0001))
    }
    
    func testFrameDelay_MoreThanTransactionMaxDuration_StartTimeTooEarly_ReturnsMinusOne() {
        let sut = fixture.sut
        sut.start()
        
        let startSystemTime = givenMoreDelayedFramesThanTransactionMaxDuration()
        
        let endSystemTime = fixture.dateProvider.systemTime()
        
        let actualFrameDelay = sut.getFrameDelay(startSystemTime - 1, endSystemTimestamp: endSystemTime)
        expect(actualFrameDelay).to(beCloseTo(-1, within: 0.0001), description: "startSystemTimeStamp starts one nanosecond before the oldest slow frame. Therefore the frame delay can't be calculated and should me 0.")
    }
    
    func testFrameDelay_FramesTrackerNotRunning_ReturnsMinusOne() {
        let sut = fixture.sut
        sut.start()
        
        let startSystemTime = givenMoreDelayedFramesThanTransactionMaxDuration()
        
        sut.stop()
        
        let endSystemTime = fixture.dateProvider.systemTime()
        
        let actualFrameDelay = sut.getFrameDelay(startSystemTime, endSystemTimestamp: endSystemTime)
        expect(actualFrameDelay) == -1.0
    }
    
    func testFrameDelay_RestartTracker_ReturnsMinusOne() {
        let sut = fixture.sut
        sut.start()
        
        let startSystemTimeStamp = givenMoreDelayedFramesThanTransactionMaxDuration()
        
        sut.stop()
        sut.start()
        
        let endSystemTime = fixture.dateProvider.systemTime()
        
        let actualFrameDelay = sut.getFrameDelay(startSystemTimeStamp, endSystemTimestamp: endSystemTime)
        expect(actualFrameDelay) == -1.0
    }
    
    func testFrameDelay_GetInfoFromBackgroundThreadWhileAdding() {
        let sut = fixture.sut
        sut.start()
        
        let startSystemTimeStamp = givenMoreDelayedFramesThanTransactionMaxDuration()
        let endSystemTime = fixture.dateProvider.systemTime()
        
        let loopSize = 1_000
        let expectation = expectation(description: "Get Frames Delays")
        expectation.expectedFulfillmentCount = loopSize
        
        for _ in 0..<loopSize {
            DispatchQueue.global().async {
                
                let actualFrameDelay = sut.getFrameDelay(startSystemTimeStamp, endSystemTimestamp: endSystemTime)
                
                expect(actualFrameDelay) >= -1
                
                expectation.fulfill()
            }
        }
        
        _ = givenMoreDelayedFramesThanTransactionMaxDuration()
        
        wait(for: [expectation], timeout: 3.0)
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
    
    private func givenMoreDelayedFramesThanTransactionMaxDuration() -> UInt64 {
        let displayLink = fixture.displayLinkWrapper
        displayLink.call()
        
        let transactionMaxDurationNS = timeIntervalToNanoseconds(SENTRY_AUTO_TRANSACTION_MAX_DURATION)
        
        while transactionMaxDurationNS >= fixture.dateProvider.systemTime() {
            _ = displayLink.slowestSlowFrame()
        }
        
        // Where the second frame starts
        return timeIntervalToNanoseconds(displayLink.frozenFrameThreshold)
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
