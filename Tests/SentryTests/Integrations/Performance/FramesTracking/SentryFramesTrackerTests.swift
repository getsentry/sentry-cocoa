@testable import _SentryPrivate
@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class SentryFramesTrackerTests: XCTestCase {
    
    private class Fixture {
        
        var displayLinkWrapper: TestDisplayLinkWrapper
        var queue: DispatchQueue
        var dateProvider = TestCurrentDateProvider()
        var notificationCenter = TestNSNotificationCenterWrapper()
        let keepDelayedFramesDuration = 10.0
        
        let slowestSlowFrameDelay: Double
        
        init() {
            displayLinkWrapper = TestDisplayLinkWrapper(dateProvider: dateProvider)
            queue = DispatchQueue(label: "SentryFramesTrackerTests", qos: .background, attributes: [.concurrent])
            
            slowestSlowFrameDelay = (displayLinkWrapper.slowestSlowFrameDuration - slowFrameThreshold(displayLinkWrapper.currentFrameRate.rawValue))
        }
        
        lazy var sut: SentryFramesTracker = SentryFramesTracker(displayLinkWrapper: displayLinkWrapper, dateProvider: dateProvider, dispatchQueueWrapper: SentryDispatchQueueWrapper(), notificationCenter: notificationCenter, keepDelayedFramesDuration: keepDelayedFramesDuration)
        
    }
    
    private var fixture: Fixture!
    
    override func setUp() {
        super.setUp()
        fixture = Fixture()
    }
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

    func testIsNotRunning_WhenNotStarted() {
        XCTAssertFalse(self.fixture.sut.isRunning)
    }
    
    func testIsRunning_WhenStarted() {
        let sut = fixture.sut
        sut.start()
        XCTAssertEqual(self.fixture.sut.isRunning, true)
    }
    
    func testStartTwice_SubscribesOnceToDisplayLink() {
        let sut = fixture.sut
        sut.start()
        sut.start()
        
        XCTAssertEqual(self.fixture.displayLinkWrapper.linkInvocations.count, 1)
    }
    
    func testStartTwice_SubscribesOnceToNotifications() {
        let sut = fixture.sut
        sut.start()
        sut.start()
        
        XCTAssertEqual(self.fixture.notificationCenter.addObserverWithObjectInvocations.invocations.count, 2)
    }
    
    func testIsNotRunning_WhenStopped() {
        let sut = fixture.sut
        sut.start()
        sut.stop()
        
        XCTAssertFalse(self.fixture.sut.isRunning)
    }
    
    func testWhenStoppedTwice_OnlyRemovesOnceFromNotifications() {
        let sut = fixture.sut
        sut.start()
        sut.stop()
        sut.stop()
        
        XCTAssertEqual(self.fixture.notificationCenter.removeObserverWithNameAndObjectInvocations.invocations.count, 2)
    }
    
    func testKeepFrames_WhenStopped() throws {
        let sut = fixture.sut
        sut.start()
        
        let displayLink = fixture.displayLinkWrapper
        displayLink.call()
        displayLink.normalFrame()
        
        sut.stop()
        
        try assert(slow: 0, frozen: 0, total: 1)
    }
    
    func testStartAfterStopped_SubscribesTwiceToDisplayLink() {
        let sut = fixture.sut
        sut.start()
        sut.stop()
        sut.start()
        
        XCTAssertEqual(sut.isRunning, true)
        XCTAssertEqual(self.fixture.displayLinkWrapper.linkInvocations.count, 2)
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
    
    func testMultipleSlowestSlowFrames() throws {
        let sut = fixture.sut
        sut.start()

        fixture.displayLinkWrapper.call()
        
        let slowFramesCount: UInt = 20
        for _ in 0..<slowFramesCount {
            _ = fixture.displayLinkWrapper.slowestSlowFrame()
        }

        try assert(slow: slowFramesCount, frozen: 0, total: slowFramesCount)
    }

    func testFrozenFrame() throws {
        let sut = fixture.sut
        sut.start()

        fixture.displayLinkWrapper.call()
        _ = fixture.displayLinkWrapper.fastestSlowFrame()
        _ = fixture.displayLinkWrapper.fastestFrozenFrame()

        try assert(slow: 1, frozen: 1, total: 2)
    }
    
    func testMultipleFastestFrozenFrames() throws {
        let sut = fixture.sut
        sut.start()

        fixture.displayLinkWrapper.call()
        
        let frozenFramesCount: UInt = 20
        for _ in 0..<frozenFramesCount {
            _ = fixture.displayLinkWrapper.fastestFrozenFrame()
        }

        try assert(slow: 0, frozen: frozenFramesCount, total: frozenFramesCount)
    }

    func testFrameRateChange() throws {
#if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
        let hub = TestHub(client: nil, andScope: nil)
        let tracer = SentryTracer(transactionContext: TransactionContext(name: "test transaction", operation: "test operation"), hub: hub)
        
        // the profiler must be running for the frames tracker to record frame rate info etc, validated in assertProfilingData()
        SentryTraceProfiler.start(withTracer: tracer.traceId)
        
        let sut = fixture.sut
        sut.start()

        fixture.displayLinkWrapper.call()
        _ = fixture.displayLinkWrapper.fastestSlowFrame()
        fixture.displayLinkWrapper.changeFrameRate(.high)
        _ = fixture.displayLinkWrapper.fastestFrozenFrame()

        try assert(slow: 1, frozen: 1, total: 2, frameRates: 2)
        
        SentryTraceProfiler.getCurrentProfiler()?.stop(for: SentryProfilerTruncationReason.normal)
        SentryTraceProfiler.resetConcurrencyTracking()
#endif // os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
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
        
        let expectedDelay = displayLink.timeEpsilon + displayLink.slowestSlowFrameDuration - slowFrameThreshold(displayLink.currentFrameRate.rawValue)
        
        let actualFrameDelay = sut.getFramesDelay(startSystemTime, endSystemTimestamp: endSystemTime)
        XCTAssertEqual(actualFrameDelay.delayDuration, expectedDelay, accuracy: 0.0001)
        XCTAssertEqual(actualFrameDelay.framesContributingToDelayCount, 4)
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
        
        let actualFrameDelay = sut.getFramesDelay(startSystemTime, endSystemTimestamp: endSystemTime)
        XCTAssertEqual(actualFrameDelay.delayDuration, expectedDelay, accuracy: 0.0001)
        XCTAssertEqual(actualFrameDelay.framesContributingToDelayCount, 2)
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
        let expectedDelay = fixture.displayLinkWrapper.slowestSlowFrameDuration - timeIntervalAfterFrameStart
        
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
        let expectedDelay = fixture.displayLinkWrapper.slowestSlowFrameDuration - slowFrameThreshold(fixture.displayLinkWrapper.currentFrameRate.rawValue)
        
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
        let expectedDelay = displayLink.slowestSlowFrameDuration - timeIntervalAfterFrameStart - timeIntervalBeforeFrameEnd
        
        testFrameDelay(timeIntervalAfterFrameStart: timeIntervalAfterFrameStart, timeIntervalBeforeFrameEnd: timeIntervalBeforeFrameEnd, expectedDelay: expectedDelay)
    }
    
    func testDelayedFrames_NoRecordedFrames_MinusOne() {
        fixture.dateProvider.advance(by: 2.0)
        
        let sut = fixture.sut
        sut.start()
        
        let startSystemTime = fixture.dateProvider.systemTime()
        
        fixture.dateProvider.advance(by: 0.001)
        
        let endSystemTime = fixture.dateProvider.systemTime()
        
        let actualFrameDelay = sut.getFramesDelay(startSystemTime, endSystemTimestamp: endSystemTime)
        XCTAssertEqual(actualFrameDelay.delayDuration, -1)
        XCTAssertEqual(actualFrameDelay.framesContributingToDelayCount, 0)
    }
    
    func testDelayedFrames_NoRecordedDelayedFrames_ReturnsZero() {
        fixture.dateProvider.advance(by: 2.0)
        
        let sut = fixture.sut
        sut.start()
        
        let displayLink = fixture.displayLinkWrapper
        displayLink.call()
        
        let startSystemTime = fixture.dateProvider.systemTime()
        
        fixture.dateProvider.advance(by: 0.001)
        
        let endSystemTime = fixture.dateProvider.systemTime()
        
        let actualFrameDelay = sut.getFramesDelay(startSystemTime, endSystemTimestamp: endSystemTime)
        XCTAssertEqual(actualFrameDelay.delayDuration, 0.0, accuracy: 0.0001)
        XCTAssertEqual(actualFrameDelay.framesContributingToDelayCount, 2)
    }
    
    func testDelayedFrames_NoRecordedDelayedFrames_ButFrameIsDelayed_ReturnsDelay() {
        fixture.dateProvider.advance(by: 2.0)
        
        let sut = fixture.sut
        sut.start()
        
        let displayLink = fixture.displayLinkWrapper
        displayLink.call()
        
        let startSystemTime = fixture.dateProvider.systemTime()
        
        let delay = 0.02
        fixture.dateProvider.advance(by: delay)
        
        let endSystemTime = fixture.dateProvider.systemTime()
        
        let expectedDelay = delay - slowFrameThreshold(fixture.displayLinkWrapper.currentFrameRate.rawValue)
        
        let actualFrameDelay = sut.getFramesDelay(startSystemTime, endSystemTimestamp: endSystemTime)
        XCTAssertEqual(actualFrameDelay.delayDuration, expectedDelay, accuracy: 0.0001)
        XCTAssertEqual(actualFrameDelay.framesContributingToDelayCount, 2)
    }
    
    func testDelayedFrames_FrameIsDelayedSmallerThanSlowFrameThreshold_ReturnsDelay() {
        fixture.dateProvider.advance(by: 2.0)
        
        let sut = fixture.sut
        sut.start()
        
        let displayLink = fixture.displayLinkWrapper
        displayLink.call()
        displayLink.normalFrame()
        
        fixture.dateProvider.advance(by: slowFrameThreshold(fixture.displayLinkWrapper.currentFrameRate.rawValue))
        
        let startSystemTime = fixture.dateProvider.systemTime()
        
        let delay = 0.0001
        fixture.dateProvider.advance(by: delay)
        
        let endSystemTime = fixture.dateProvider.systemTime()
        
        let expectedDelay = delay
        
        let actualFrameDelay = sut.getFramesDelay(startSystemTime, endSystemTimestamp: endSystemTime)
        XCTAssertEqual(
            actualFrameDelay.delayDuration, expectedDelay, accuracy: 0.0001)
        XCTAssertEqual(actualFrameDelay.framesContributingToDelayCount, 1)
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
        
        let actualFrameDelay = sut.getFramesDelay(startSystemTime, endSystemTimestamp: endSystemTime)
        XCTAssertEqual(actualFrameDelay.delayDuration, expectedDelay, accuracy: 0.0001)
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
        
        let expectedDelay = displayLink.slowestSlowFrameDuration - slowFrameThreshold(displayLink.currentFrameRate.rawValue)
        
        let actualFrameDelay = sut.getFramesDelay(startSystemTime, endSystemTimestamp: endSystemTime)
        XCTAssertEqual(actualFrameDelay.delayDuration, expectedDelay, accuracy: 0.0001)
    }
    
    func testFrameDelay_WithStartBeforeEnd_ReturnsMinusOne() {
        let sut = fixture.sut
        sut.start()
        
        let displayLink = fixture.displayLinkWrapper
        displayLink.call()
        _ = displayLink.slowestSlowFrame()
        
        let actualFrameDelay = sut.getFramesDelay(1, endSystemTimestamp: 0)
        XCTAssertEqual(actualFrameDelay.delayDuration, -1.0)
    }
    
    func testFrameDelay_LongestTimeStamp_ReturnsMinusOne() {
        let sut = fixture.sut
        sut.start()
        
        let displayLink = fixture.displayLinkWrapper
        displayLink.call()
        _ = displayLink.slowestSlowFrame()

        let actualFrameDelay = sut.getFramesDelay(0, endSystemTimestamp: UInt64.max)
        XCTAssertEqual(actualFrameDelay.delayDuration, -1.0)
    }
    
    func testFrameDelay_KeepAddingSlowFrames_OnlyTheMaxDurationFramesReturned() {
        let sut = fixture.sut
        sut.start()
        
        let (startSystemTime, _, expectedDelay) = givenMoreDelayedFramesThanTransactionMaxDuration(sut)
        
        let endSystemTime = fixture.dateProvider.systemTime()

        let actualFrameDelay = sut.getFramesDelay(startSystemTime, endSystemTimestamp: endSystemTime)
        XCTAssertEqual(actualFrameDelay.delayDuration, expectedDelay, accuracy: 0.0001)
    }
    
    func testFrameDelay_MoreThanMaxDuration_FrameInformationMissing_DelayReturned() {
        let sut = fixture.sut
        let displayLink = fixture.displayLinkWrapper
        sut.start()
        
        let (startSystemTime, _, slowFramesDelay) = givenMoreDelayedFramesThanTransactionMaxDuration(sut)
        
        let delayWithoutFrameRecord = 2.0
        fixture.dateProvider.advance(by: delayWithoutFrameRecord)
        let endSystemTime = fixture.dateProvider.systemTime()
        
        let delayNotRecorded = delayWithoutFrameRecord - slowFrameThreshold(displayLink.currentFrameRate.rawValue)
        let expectedDelay = slowFramesDelay + delayNotRecorded

        let actualFrameDelay = sut.getFramesDelay(startSystemTime, endSystemTimestamp: endSystemTime)
        XCTAssertEqual(actualFrameDelay.delayDuration, expectedDelay, accuracy: 0.0001)
    }
    
    func testFrameDelay_MoreThanMaxDuration_StartTimeTooEarly_ReturnsMinusOne() {
        let sut = fixture.sut
        sut.start()
        
        let (startSystemTime, _, _) = givenMoreDelayedFramesThanTransactionMaxDuration(sut)
        
        let endSystemTime = fixture.dateProvider.systemTime()
        
        let actualFrameDelay = sut.getFramesDelay(startSystemTime - 1, endSystemTimestamp: endSystemTime)
        XCTAssertEqual(actualFrameDelay.delayDuration, -1, accuracy: 0.0001, "startSystemTimeStamp starts one nanosecond before the oldest slow frame. Therefore the frame delay can't be calculated and should me 0.")
    }
    
    func testFrameDelay_FramesTrackerNotRunning_ReturnsMinusOne() {
        let sut = fixture.sut
        sut.start()
        
        let startSystemTime = fixture.dateProvider.systemTime()
        
        let displayLink = fixture.displayLinkWrapper
        displayLink.call()
        _ = displayLink.slowestSlowFrame()
        
        let endSystemTime = fixture.dateProvider.systemTime()
        
        sut.stop()
        
        let actualFrameDelay = sut.getFramesDelay(startSystemTime, endSystemTimestamp: endSystemTime)
        XCTAssertEqual(actualFrameDelay.delayDuration, -1.0)
    }
    
    func testFrameDelay_RestartTracker_ReturnsMinusOne() {
        let sut = fixture.sut
        sut.start()
        
        let (startSystemTime, _, _) = givenMoreDelayedFramesThanTransactionMaxDuration(sut)
        
        sut.stop()
        sut.start()
        
        let endSystemTime = fixture.dateProvider.systemTime()
        
        let actualFrameDelay = sut.getFramesDelay(startSystemTime, endSystemTimestamp: endSystemTime)
        XCTAssertEqual(actualFrameDelay.delayDuration, -1.0)
    }
    
    func testFrameDelay_GetInfoFromBackgroundThreadWhileAdding() {
        let sut = fixture.sut
        sut.start()
        
        let (startSystemTime, _, _) = givenMoreDelayedFramesThanTransactionMaxDuration(sut)
        let endSystemTime = fixture.dateProvider.systemTime()
        
        let loopSize = 1_000
        let expectation = expectation(description: "Get Frames Delays")
        expectation.expectedFulfillmentCount = loopSize
        
        for _ in 0..<loopSize {
            DispatchQueue.global().async {
                
                let actualFrameDelay = sut.getFramesDelay(startSystemTime, endSystemTimestamp: endSystemTime)
                
                XCTAssertGreaterThanOrEqual(actualFrameDelay.delayDuration, -1)
                
                expectation.fulfill()
            }
        }
        
        _ = givenMoreDelayedFramesThanTransactionMaxDuration(sut)
        
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testGetFramesDelayOnTightLoop_WhileKeepAddingDelayedFrames() {
        let displayLink = fixture.displayLinkWrapper
        let dateProvider = fixture.dateProvider
        
        let sut = fixture.sut
        sut.start()
        
        for _ in 0..<100 {
            displayLink.normalFrame()
        }
        
        let expectation = expectation(description: "Get Frames Delays")
        
        DispatchQueue.global().async {
            
            for _ in 0..<1_000 {

                let endSystemTimestamp = dateProvider.systemTime()
                let startSystemTimestamp = endSystemTimestamp - timeIntervalToNanoseconds(1.0)
                
                let frameDelay = sut.getFramesDelay(startSystemTimestamp, endSystemTimestamp: endSystemTimestamp)
                
                XCTAssertLessThanOrEqual(frameDelay.delayDuration, 1.0)
            }
            
            expectation.fulfill()
        }
        
        for _ in 0..<1_000 {
            displayLink.frameWith(delay: 1.0)
        }
        
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testAddMultipleListeners_AllCalledWithSameDate() {
        let sut = fixture.sut
        let listener1 = FrameTrackerListener()
        let listener2 = FrameTrackerListener()
        sut.start()
        sut.add(listener1)
        sut.add(listener2)
        
        fixture.dateProvider.driftTimeForEveryRead = true

        fixture.displayLinkWrapper.normalFrame()
        var expectedFrameDate = fixture.dateProvider.date()
        expectedFrameDate.addTimeInterval(-fixture.dateProvider.driftTimeInterval)

        XCTAssertEqual(listener1.newFrameInvocations.count, 1)
        XCTAssertEqual(listener1.newFrameInvocations.first?.timeIntervalSince1970, expectedFrameDate.timeIntervalSince1970)
        
        XCTAssertEqual(listener2.newFrameInvocations.count, 1)
        XCTAssertEqual(listener2.newFrameInvocations.first?.timeIntervalSince1970, expectedFrameDate.timeIntervalSince1970)
    }
    
    func testListenerAreAddedInMainThread() {
        let dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
        let sut = SentryFramesTracker(displayLinkWrapper: fixture.displayLinkWrapper, dateProvider: fixture.dateProvider, dispatchQueueWrapper: dispatchQueueWrapper, notificationCenter: fixture.notificationCenter, keepDelayedFramesDuration: fixture.keepDelayedFramesDuration)
        let listener = FrameTrackerListener()
        
        sut.add(listener)
        
        XCTAssertEqual(dispatchQueueWrapper.blockOnMainInvocations.count, 1)
    }

    func testRemoveListener() {
        let sut = fixture.sut
        let listener = FrameTrackerListener()
        sut.start()
        sut.add(listener)
        sut.remove(listener)

        fixture.displayLinkWrapper.normalFrame()

        XCTAssertEqual(listener.newFrameInvocations.count, 0)
    }
    
    func testListenerNotCalledAfterCallingStop() {
        let sut = fixture.sut
        let listener1 = FrameTrackerListener()
        let listener2 = FrameTrackerListener()
        sut.start()
        sut.add(listener1)
        sut.stop()
        sut.start()
        sut.add(listener2)

        fixture.displayLinkWrapper.normalFrame()

        XCTAssertEqual(listener1.newFrameInvocations.count, 0)
        XCTAssertEqual(listener2.newFrameInvocations.count, 1)
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
            
            let notificationCenter = TestNSNotificationCenterWrapper()
            notificationCenter.ignoreAddObserver = true
            
            let displayLinkWrapper = fixture.displayLinkWrapper
            displayLinkWrapper.ignoreLinkInvocations = true
            
            let sut = SentryFramesTracker(displayLinkWrapper: displayLinkWrapper, dateProvider: fixture.dateProvider, dispatchQueueWrapper: SentryDispatchQueueWrapper(), notificationCenter: notificationCenter, keepDelayedFramesDuration: 0)
            
            sut.start()
        }
        sutIsDeallocatedAfterCallingMe()
        
        XCTAssertEqual(1, fixture.displayLinkWrapper.invalidateInvocations.count)
    }
    
    func testFrameTrackerPauses_WhenAppGoesToBackground() {
        let sut = fixture.sut
        sut.start()
        
        fixture.notificationCenter.post(Notification(name: CrossPlatformApplication.willResignActiveNotification))
        
        XCTAssertFalse(sut.isRunning)
    }
    
    func testFrameTrackerUnpauses_WhenAppGoesToForeground() {
        let sut = fixture.sut
        sut.start()
        
        var callbackCalls = 0
        let listener = FrameTrackerListener()
        listener.callback = {
            callbackCalls += 1
        }
        sut.add(listener)
        
        fixture.notificationCenter.post(Notification(name: CrossPlatformApplication.willResignActiveNotification))
        
        fixture.notificationCenter.post(Notification(name: CrossPlatformApplication.didBecomeActiveNotification))
        
        // Ensure to keep listeners when moving to background
        fixture.displayLinkWrapper.normalFrame()
        XCTAssertEqual(callbackCalls, 1)
        
        XCTAssertEqual(sut.isRunning, true)
    }
    
    func testUnpause_ResetsPreviousFrameTimestamp_ToAvoidWrongMetrics() throws {
        let sut = fixture.sut
        sut.start()
        
        // Simulate some frames to establish a previous frame timestamp
        fixture.displayLinkWrapper.call()
        fixture.displayLinkWrapper.normalFrame()
        fixture.displayLinkWrapper.normalFrame()
        
        // Pause the tracker
        fixture.notificationCenter.post(Notification(name: CrossPlatformApplication.willResignActiveNotification))
        
        // Verify it's paused
        XCTAssertFalse(sut.isRunning)
        
        // Unpause and verify the previous frame timestamp is reset
        fixture.notificationCenter.post(Notification(name: CrossPlatformApplication.didBecomeActiveNotification))
        XCTAssertTrue(sut.isRunning)
        
        // The next frame should be treated as the first frame (previousFrameTimestamp == SentryPreviousFrameInitialValue)
        // This means it won't be classified as slow/frozen even if there was a long pause
        fixture.displayLinkWrapper.call()
        
        // Should not detect any slow or frozen frames after unpausing
        try assert(slow: 0, frozen: 0, total: 2)
    }
    
    func testUnpause_WhenAlreadyRunning_DoesNotResetTimestamp() throws {
        let sut = fixture.sut
        sut.start()
        
        // Simulate some frames
        fixture.displayLinkWrapper.call()
        fixture.displayLinkWrapper.normalFrame()
        
        // Try to unpause when already running
        fixture.notificationCenter.post(Notification(name: CrossPlatformApplication.didBecomeActiveNotification))
        
        // Should still be running
        XCTAssertTrue(sut.isRunning)
        
        // Continue with normal frames
        fixture.displayLinkWrapper.normalFrame()
        
        // Should have normal frame counting behavior
        try assert(slow: 0, frozen: 0, total: 2)
    }
    
    func testUnpause_AfterBackgroundForegroundTransition_ResetsTimestamp() throws {
        let sut = fixture.sut
        sut.start()
        
        // Simulate some frames
        fixture.displayLinkWrapper.call()
        fixture.displayLinkWrapper.normalFrame()
        
        // Simulate app going to background
        fixture.notificationCenter.post(Notification(name: CrossPlatformApplication.willResignActiveNotification))
        XCTAssertFalse(sut.isRunning)
        
        // Simulate a long time in background
        fixture.dateProvider.advance(by: 10.0)
        
        // Simulate app coming to foreground
        fixture.notificationCenter.post(Notification(name: CrossPlatformApplication.didBecomeActiveNotification))
        XCTAssertTrue(sut.isRunning)
        
        // The next frame should not be classified as slow/frozen due to the long background time
        fixture.displayLinkWrapper.call()
        
        // Should not detect any slow or frozen frames
        try assert(slow: 0, frozen: 0, total: 1)
    }
    
    func testUnpause_MultipleTimes_AlwaysResetsTimestamp() throws {
        let sut = fixture.sut
        sut.start()
        
        // Simulate some frames
        fixture.displayLinkWrapper.call()
        fixture.displayLinkWrapper.normalFrame()
        
        // Pause and unpause multiple times
        for _ in 0..<3 {
            fixture.notificationCenter.post(Notification(name: CrossPlatformApplication.willResignActiveNotification))
            fixture.dateProvider.advance(by: 2.0) // Long pause each time
            fixture.notificationCenter.post(Notification(name: CrossPlatformApplication.didBecomeActiveNotification))
            
            // Each unpause should reset the timestamp
            fixture.displayLinkWrapper.call()
            fixture.displayLinkWrapper.normalFrame()
        }
        
        // Should not detect any slow or frozen frames from the pauses
        try assert(slow: 0, frozen: 0, total: 4)
    }
    
    func testUnpause_WithDelayedFramesTracker_ResetsPreviousFrameSystemTimestamp() {
        let sut = fixture.sut
        sut.start()
        
        // Simulate some frames to establish system timestamps
        fixture.displayLinkWrapper.call()
        fixture.displayLinkWrapper.normalFrame()
        
        // Pause the tracker
        fixture.notificationCenter.post(Notification(name: CrossPlatformApplication.willResignActiveNotification))
        
        // Advance time significantly
        fixture.dateProvider.advance(by: 5.0)
        
        // Unpause the tracker
        fixture.notificationCenter.post(Notification(name: CrossPlatformApplication.didBecomeActiveNotification))
        
        // The delayed frames tracker should also have its previous frame system timestamp reset
        // This prevents false delay calculations after unpausing
        let startSystemTime = fixture.dateProvider.systemTime()
        fixture.dateProvider.advance(by: 0.001)
        let endSystemTime = fixture.dateProvider.systemTime()
        
        let frameDelay = sut.getFramesDelay(startSystemTime, endSystemTimestamp: endSystemTime)
        
        // Should not report any delay from the pause period
        XCTAssertEqual(frameDelay.delayDuration, 0.001, accuracy: 0.0001)
    }

#if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
    func testResetProfilingTimestamps_FromBackgroundThread() {
        let sut = fixture.sut
        sut.start()
        
        let queue = DispatchQueue(label: "reset profiling timestamps", attributes: [.initiallyInactive, .concurrent])
        
        for _ in 0..<10_000 {
            queue.async {
                sut.resetProfilingTimestamps()
            }
        }
        
        queue.activate()
        
        for _ in 0..<1_000 {
            self.fixture.displayLinkWrapper.normalFrame()
        }
    }
#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    
    private func givenMoreDelayedFramesThanTransactionMaxDuration(_ framesTracker: SentryFramesTracker) -> (UInt64, UInt, Double) {
        let displayLink = fixture.displayLinkWrapper
        displayLink.call()
        
        let slowFramesCountBeforeAddingFrames = framesTracker.currentFrames().slow
        
        // We have to add the delay of the slowest frame because we remove frames
        // based on the endTimeStamp not the start time stamp.
        let keepAddingFramesSystemTime = fixture.dateProvider.systemTime() + timeIntervalToNanoseconds(fixture.keepDelayedFramesDuration + fixture.slowestSlowFrameDelay)
        
        while fixture.dateProvider.systemTime() < keepAddingFramesSystemTime {
            _ = displayLink.slowestSlowFrame()
        }
        
        // We have to remove 1 slow frame cause one will be older than transactionMaxDurationNS
        let slowFramesCount = framesTracker.currentFrames().slow - slowFramesCountBeforeAddingFrames - 1
        
        let slowFramesDelay = fixture.slowestSlowFrameDelay * Double(slowFramesCount)
        
        // Where the second frame starts
        return (timeIntervalToNanoseconds(displayLink.slowestSlowFrameDuration), slowFramesCount, slowFramesDelay)
    }
}

private class FrameTrackerListener: NSObject, SentryFramesTrackerListener {
    
    var newFrameInvocations = Invocations<Date>()
    var callback: (() -> Void)?
    func framesTrackerHasNewFrame(_ newFrameDate: Date) {
        newFrameInvocations.record(newFrameDate)
        callback?()
    }
}

private extension SentryFramesTrackerTests {
    func assert(slow: UInt? = nil, frozen: UInt? = nil, total: UInt? = nil, frameRates: UInt? = nil) throws {
        let currentFrames = fixture.sut.currentFrames()
        if let total = total {
            XCTAssertEqual(currentFrames.total, total)
        }
        if let slow = slow {
            XCTAssertEqual(currentFrames.slow, slow)
        }
        if let frozen = frozen {
            XCTAssertEqual(currentFrames.frozen, frozen)
        }

#if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
        try  assertProfilingData(slow: slow, frozen: frozen, frameRates: frameRates)
#endif
    }

#if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
    func assertProfilingData(slow: UInt? = nil, frozen: UInt? = nil, frameRates: UInt? = nil) throws {
        if sentry_threadSanitizerIsPresent() {
            // profiling data will not have been gathered with TSAN running
            return
        }
        
        func assertFrameInfo(frame: [String: NSNumber]) throws {
            XCTAssertNotNil(frame["timestamp"], "Expected a timestamp for the frame.")
            XCTAssertNotNil(frame["value"], "Expected a duration value for the frame.")
        }

        let currentFrames = fixture.sut.currentFrames()

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
