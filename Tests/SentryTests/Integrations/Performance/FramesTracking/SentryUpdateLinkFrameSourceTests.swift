@_spi(Private) import SentryTestUtils
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
@testable import _SentryPrivate
import XCTest

#if os(iOS) || os(tvOS)
/// Tests ``SentryUpdateLinkFrameSource`` through the ``SentryFramesTracker`` it reports to.
final class SentryUpdateLinkFrameSourceTests: XCTestCase {

    private final class TestMainRunLoopActivityObserver: SentryMainRunLoopActivityObserving {
        private var handler: ((CFRunLoopActivity) -> Void)?
        var startInvocations = 0
        var stopInvocations = 0

        func start(handler: @escaping (CFRunLoopActivity) -> Void) {
            startInvocations += 1
            self.handler = handler
        }

        func stop() {
            stopInvocations += 1
            handler = nil
        }

        func observe(_ activity: CFRunLoopActivity) {
            handler?(activity)
        }
    }

    private final class TestUIUpdateObserver: SentryUIUpdateObserving {
        private var handler: ((CFTimeInterval) -> Void)?
        var requiresContinuousUpdates = false
        var startInvocations = 0
        var stopInvocations = 0

        func start(handler: @escaping (CFTimeInterval) -> Void) {
            startInvocations += 1
            self.handler = handler
        }

        func stop() {
            stopInvocations += 1
            handler = nil
        }

        func update(frameRate: Double = 60) {
            handler?(1 / frameRate)
        }

        func update(frameDuration: CFTimeInterval) {
            handler?(frameDuration)
        }
    }

    private final class TestListener: NSObject, SentryFramesTrackerListener {
        var newFrameDates: [Date] = []

        func framesTrackerHasNewFrame(_ newFrameDate: Date) {
            newFrameDates.append(newFrameDate)
        }
    }

    private final class Fixture {
        let dateProvider = TestCurrentDateProvider()
        let notificationCenter = TestNSNotificationCenterWrapper()
        let runLoopObserver = TestMainRunLoopActivityObserver()
        let uiUpdateObserver = TestUIUpdateObserver()

        let slowFrameThreshold = SentryFramesTracker.slowFrameThreshold(60)

        init() {
            // A system time of zero means no timestamp to both the frame source and the delayed frames tracker.
            dateProvider.advance(by: 1)
        }

        lazy var sut = SentryFramesTracker(
            frameSource: SentryUpdateLinkFrameSource(dateProvider: dateProvider, runLoopObserver: runLoopObserver, uiUpdateObserver: uiUpdateObserver),
            dateProvider: dateProvider,
            dispatchQueueWrapper: SentryDispatchQueueWrapper(),
            notificationCenter: notificationCenter,
            delayedFramesTracker: TestDelayedWrapper(keepDelayedFramesDuration: 10, dateProvider: dateProvider)
        )

        /// The main thread works on one thing for the given duration, and then the run loop waits.
        func work(for duration: TimeInterval) {
            runLoopObserver.observe(.beforeTimers)
            dateProvider.advance(by: duration)
            runLoopObserver.observe(.beforeWaiting)
        }

        /// The run loop waits for the given duration, and then wakes up.
        func wait(for duration: TimeInterval) {
            runLoopObserver.observe(.beforeWaiting)
            dateProvider.advance(by: duration)
            runLoopObserver.observe(.afterWaiting)
        }
    }

    private var fixture: Fixture!

    override func setUp() {
        super.setUp()
        fixture = Fixture()
    }

    override func tearDown() {
        fixture.sut.stop()
        fixture = nil
        super.tearDown()
    }

    // MARK: - Start and stop

    func testStart_shouldObserveRunLoopAndUIUpdates() {
        // -- Arrange --
        let sut = fixture.sut

        // -- Act --
        sut.start()

        // -- Assert --
        XCTAssertTrue(sut.isRunning)
        XCTAssertEqual(fixture.runLoopObserver.startInvocations, 1)
        XCTAssertEqual(fixture.uiUpdateObserver.startInvocations, 1)
    }

    func testStop_shouldStopObserving() {
        // -- Arrange --
        let sut = fixture.sut
        sut.start()

        // -- Act --
        sut.stop()

        // -- Assert --
        XCTAssertFalse(sut.isRunning)
        XCTAssertEqual(fixture.runLoopObserver.stopInvocations, 1)
        XCTAssertEqual(fixture.uiUpdateObserver.stopInvocations, 1)
    }

    func testWillResignActive_whenRunning_shouldStopObservingUntilActiveAgain() {
        // -- Arrange --
        let sut = fixture.sut
        sut.start()

        // -- Act --
        fixture.notificationCenter.post(Notification(name: UIApplication.willResignActiveNotification))
        let observingStoppedCount = fixture.runLoopObserver.stopInvocations
        fixture.notificationCenter.post(Notification(name: UIApplication.didBecomeActiveNotification))

        // -- Assert --
        XCTAssertEqual(observingStoppedCount, 1)
        XCTAssertEqual(fixture.runLoopObserver.startInvocations, 2)
        XCTAssertEqual(fixture.uiUpdateObserver.startInvocations, 2)
    }

    func testSetDisplayLinkWrapper_shouldReplaceUpdateLinkSourceWithDisplayLink() {
        // -- Arrange --
        let sut = fixture.sut
        let displayLinkWrapper = TestDisplayLinkWrapper(dateProvider: fixture.dateProvider)

        // -- Act --
        sut.setDisplayLinkWrapper(displayLinkWrapper)
        sut.start()
        displayLinkWrapper.call()
        displayLinkWrapper.normalFrame()

        // -- Assert --
        XCTAssertEqual(fixture.runLoopObserver.startInvocations, 0)
        XCTAssertGreaterThan(fixture.runLoopObserver.stopInvocations, 0)
        XCTAssertEqual(displayLinkWrapper.linkInvocations.count, 1)
        XCTAssertEqual(sut.currentFrames().total, 1)
    }

    // MARK: - Slow and frozen frames

    func testCurrentFrames_whenMainThreadWorksLongerThanSlowFrameThreshold_shouldCountSlowFrame() {
        // -- Arrange --
        let sut = fixture.sut
        sut.start()

        // -- Act --
        fixture.work(for: fixture.slowFrameThreshold + 0.001)

        // -- Assert --
        let frames = sut.currentFrames()
        XCTAssertEqual(frames.slow, 1)
        XCTAssertEqual(frames.frozen, 0)
    }

    func testCurrentFrames_whenMainThreadWorksLongerThanFrozenFrameThreshold_shouldCountFrozenFrame() {
        // -- Arrange --
        let sut = fixture.sut
        sut.start()

        // -- Act --
        fixture.work(for: 0.701)

        // -- Assert --
        let frames = sut.currentFrames()
        XCTAssertEqual(frames.slow, 0)
        XCTAssertEqual(frames.frozen, 1)
    }

    func testCurrentFrames_whenMainThreadWorksShorterThanSlowFrameThreshold_shouldNotCountSlowFrame() {
        // -- Arrange --
        let sut = fixture.sut
        sut.start()

        // -- Act --
        for _ in 0..<100 {
            fixture.work(for: fixture.slowFrameThreshold - 0.001)
        }

        // -- Assert --
        let frames = sut.currentFrames()
        XCTAssertEqual(frames.slow, 0)
        XCTAssertEqual(frames.frozen, 0)
    }

    func testCurrentFrames_whenRunLoopIterationsDontWait_shouldClassifyEachIterationOnItsOwn() {
        // -- Arrange --
        let sut = fixture.sut
        sut.start()

        // -- Act --
        // Many short pieces of work back to back keep the main thread busy, but it can still
        // produce frames in between.
        fixture.runLoopObserver.observe(.afterWaiting)
        for _ in 0..<100 {
            fixture.dateProvider.advance(by: 0.01)
            fixture.runLoopObserver.observe(.beforeTimers)
        }

        // -- Assert --
        let frames = sut.currentFrames()
        XCTAssertEqual(frames.slow, 0)
        XCTAssertEqual(frames.frozen, 0)
    }

    func testCurrentFrames_whenRunLoopWaits_shouldNotCountFrozenFrame() {
        // -- Arrange --
        let sut = fixture.sut
        sut.start()

        // -- Act --
        fixture.wait(for: 5)

        // -- Assert --
        let frames = sut.currentFrames()
        XCTAssertEqual(frames.slow, 0)
        XCTAssertEqual(frames.frozen, 0)
    }

    func testCurrentFrames_whenFrameRateIs120_shouldUseSlowFrameThresholdOfThatFrameRate() {
        // -- Arrange --
        let sut = fixture.sut
        sut.start()
        fixture.uiUpdateObserver.update(frameRate: 120)

        // -- Act --
        // Slow at 120 fps, but not at 60 fps.
        fixture.work(for: 0.010)

        // -- Assert --
        XCTAssertEqual(sut.currentFrames().slow, 1)
    }

    func testCurrentFrames_whenFrameDurationIsNotOfADisplay_shouldKeepFrameRate() {
        // -- Arrange --
        let sut = fixture.sut
        sut.start()

        // -- Act --
        fixture.uiUpdateObserver.update(frameDuration: 0)
        fixture.uiUpdateObserver.update(frameDuration: -1)
        fixture.uiUpdateObserver.update(frameDuration: 0.000001)
        fixture.uiUpdateObserver.update(frameDuration: 10)
        fixture.work(for: 0.010)

        // -- Assert --
        XCTAssertEqual(sut.currentFrames().slow, 0)
    }

    // MARK: - Total frames

    func testCurrentFrames_whenTimePasses_shouldExtrapolateTotalFrames() {
        // -- Arrange --
        let sut = fixture.sut
        sut.start()

        // -- Act --
        fixture.wait(for: 1)

        // -- Assert --
        XCTAssertEqual(sut.currentFrames().total, 60)
    }

    func testCurrentFrames_whenFrameIsDelayed_shouldCountItAsOneFrame() {
        // -- Arrange --
        let sut = fixture.sut
        sut.start()

        // -- Act --
        fixture.wait(for: 1)
        fixture.work(for: 2)
        fixture.wait(for: 1)

        // -- Assert --
        XCTAssertEqual(sut.currentFrames().total, 121)
    }

    func testCurrentFrames_whenFrameRateChanges_shouldCountFramesWithFrameRateOfTheirTime() {
        // -- Arrange --
        let sut = fixture.sut
        sut.start()

        // -- Act --
        fixture.wait(for: 1)
        fixture.uiUpdateObserver.update(frameRate: 120)
        fixture.wait(for: 1)

        // -- Assert --
        XCTAssertEqual(sut.currentFrames().total, 180)
    }

    func testCurrentFrames_whenReadWhileMainThreadIsBlocked_shouldNotCountFramesOfBlockedTime() {
        // -- Arrange --
        let sut = fixture.sut
        sut.start()
        fixture.wait(for: 1)

        // -- Act --
        // A span that starts or finishes on another thread reads the frames while the main thread
        // is blocked.
        fixture.dateProvider.advance(by: 1.9)
        let totalWhileBlocked = sut.currentFrames().total
        fixture.dateProvider.advance(by: 0.1)
        fixture.runLoopObserver.observe(.beforeWaiting)
        let totalAfterBlock = sut.currentFrames().total

        // -- Assert --
        XCTAssertEqual(totalWhileBlocked, 61)
        XCTAssertEqual(totalAfterBlock, 61)
    }

    func testCurrentFrames_whenMainThreadIsBlocked_shouldNeverDecrease() {
        // -- Arrange --
        let sut = fixture.sut
        sut.start()
        fixture.wait(for: 0.5)
        var totals: [UInt] = []

        // -- Act --
        for _ in 0..<40 {
            fixture.dateProvider.advance(by: 0.005)
            totals.append(sut.currentFrames().total)
        }
        fixture.runLoopObserver.observe(.beforeWaiting)
        totals.append(sut.currentFrames().total)
        fixture.wait(for: 0.1)
        totals.append(sut.currentFrames().total)

        // -- Assert --
        XCTAssertEqual(totals, totals.sorted())
        XCTAssertEqual(totals.last, 37)
    }

    func testCurrentFrames_whenFrameRateChangesWhileMainThreadIsBlocked_shouldCountBlockedTimeAsOneFrame() {
        // -- Arrange --
        let sut = fixture.sut
        sut.start()
        fixture.runLoopObserver.observe(.afterWaiting)

        // -- Act --
        // UIKit reports the UI update, and with it the frame rate, from within the work that
        // blocks the main thread.
        fixture.dateProvider.advance(by: 1)
        fixture.uiUpdateObserver.update(frameRate: 120)
        fixture.dateProvider.advance(by: 0.01)
        fixture.runLoopObserver.observe(.beforeWaiting)

        // -- Assert --
        XCTAssertEqual(sut.currentFrames().total, 1)
        XCTAssertEqual(sut.currentFrames().frozen, 1)
    }

    func testCurrentFrames_whenStoppedWhileMainThreadIsBlocked_shouldCountBlockedTimeAsOneFrame() {
        // -- Arrange --
        let sut = fixture.sut
        sut.start()
        fixture.wait(for: 1)

        // -- Act --
        fixture.dateProvider.advance(by: 2)
        fixture.notificationCenter.post(Notification(name: UIApplication.willResignActiveNotification))

        // -- Assert --
        XCTAssertEqual(sut.currentFrames().total, 61)
    }

    func testCurrentFrames_whenNotActive_shouldNotCountFrames() {
        // -- Arrange --
        let sut = fixture.sut
        sut.start()
        fixture.dateProvider.advance(by: 1)

        // -- Act --
        fixture.notificationCenter.post(Notification(name: UIApplication.willResignActiveNotification))
        fixture.dateProvider.advance(by: 10)
        fixture.notificationCenter.post(Notification(name: UIApplication.didBecomeActiveNotification))
        fixture.dateProvider.advance(by: 1)

        // -- Assert --
        XCTAssertEqual(sut.currentFrames().total, 120)
    }

    func testResetFrames_whenRunning_shouldStartCountingFromZero() {
        // -- Arrange --
        let sut = fixture.sut
        sut.start()
        fixture.work(for: 1)
        fixture.wait(for: 1)

        // -- Act --
        sut.resetFrames()
        fixture.wait(for: 0.5)

        // -- Assert --
        let frames = sut.currentFrames()
        XCTAssertEqual(frames.total, 30)
        XCTAssertEqual(frames.frozen, 0)
    }

    // MARK: - Frames delay

    func testGetFramesDelay_whenMainThreadWasBlocked_shouldReturnTimeOverSlowFrameThreshold() {
        // -- Arrange --
        let sut = fixture.sut
        sut.start()
        let start = fixture.dateProvider.systemTime()

        // -- Act --
        fixture.wait(for: 1)
        fixture.work(for: 0.5)
        fixture.wait(for: 1)

        // -- Assert --
        let delay = sut.getFramesDelay(start, endSystemTimestamp: fixture.dateProvider.systemTime())
        XCTAssertEqual(delay.delayDuration, 0.5 - fixture.slowFrameThreshold, accuracy: 0.0001)
    }

    func testGetFramesDelay_whenMainThreadStillBlocked_shouldIncludeOngoingDelay() {
        // -- Arrange --
        let sut = fixture.sut
        sut.start()
        let start = fixture.dateProvider.systemTime()
        fixture.wait(for: 1)

        // -- Act --
        // The main thread started to work and didn't get back to the run loop yet.
        fixture.runLoopObserver.observe(.beforeTimers)
        fixture.dateProvider.advance(by: 0.5)

        // -- Assert --
        let delay = sut.getFramesDelay(start, endSystemTimestamp: fixture.dateProvider.systemTime())
        XCTAssertEqual(delay.delayDuration, 0.5 - fixture.slowFrameThreshold, accuracy: 0.0001)
    }

    func testGetFramesDelay_whenRunLoopWaiting_shouldNotCountWaitingAsDelay() {
        // -- Arrange --
        let sut = fixture.sut
        sut.start()
        let start = fixture.dateProvider.systemTime()
        fixture.work(for: 0.001)

        // -- Act --
        fixture.dateProvider.advance(by: 5)

        // -- Assert --
        let delay = sut.getFramesDelay(start, endSystemTimestamp: fixture.dateProvider.systemTime())
        XCTAssertEqual(delay.delayDuration, 0, accuracy: 0.0001)
    }

    func testGetFramesDelay_whenNoRunLoopActivityYet_shouldReturnMinusOne() {
        // -- Arrange --
        let sut = fixture.sut
        sut.start()
        let start = fixture.dateProvider.systemTime()

        // -- Act --
        fixture.dateProvider.advance(by: 1)

        // -- Assert --
        let delay = sut.getFramesDelay(start, endSystemTimestamp: fixture.dateProvider.systemTime())
        XCTAssertEqual(delay.delayDuration, -1, accuracy: 0.0001)
    }

    // MARK: - Listeners

    func testUIUpdate_whenListenerAdded_shouldReportNewFrame() {
        // -- Arrange --
        let sut = fixture.sut
        sut.start()
        let listener = TestListener()
        sut.addListener(listener)

        // -- Act --
        fixture.uiUpdateObserver.update()
        fixture.uiUpdateObserver.update()

        // -- Assert --
        XCTAssertEqual(listener.newFrameDates, [fixture.dateProvider.date(), fixture.dateProvider.date()])
    }

    func testRunLoopActivity_whenListenerAdded_shouldNotReportNewFrame() {
        // -- Arrange --
        let sut = fixture.sut
        sut.start()
        let listener = TestListener()
        sut.addListener(listener)

        // -- Act --
        fixture.work(for: 1)

        // -- Assert --
        XCTAssertEqual(listener.newFrameDates, [])
    }

    func testAddListener_shouldRequireContinuousUpdatesUntilRemoved() {
        // -- Arrange --
        let sut = fixture.sut
        sut.start()
        let listener = TestListener()

        // -- Act --
        let requiredBeforeAdding = fixture.uiUpdateObserver.requiresContinuousUpdates
        sut.addListener(listener)
        let requiredAfterAdding = fixture.uiUpdateObserver.requiresContinuousUpdates
        sut.removeListener(listener)
        let requiredAfterRemoving = fixture.uiUpdateObserver.requiresContinuousUpdates

        // -- Assert --
        XCTAssertFalse(requiredBeforeAdding)
        XCTAssertTrue(requiredAfterAdding)
        XCTAssertFalse(requiredAfterRemoving)
    }

    func testUIUpdate_whenListenerDeallocated_shouldStopRequiringContinuousUpdates() {
        // -- Arrange --
        let sut = fixture.sut
        sut.start()
        autoreleasepool {
            sut.addListener(TestListener())
        }

        // -- Act --
        fixture.uiUpdateObserver.update()

        // -- Assert --
        XCTAssertFalse(fixture.uiUpdateObserver.requiresContinuousUpdates)
    }
}

/// Tests the part of ``SentryDelayedFramesTracker`` that ``SentryUpdateLinkFrameSource`` needs.
final class SentryDelayedFramesTrackerNoFrameInFlightTests: XCTestCase {

    func testGetFramesDelay_whenNoFrameInFlight_shouldNotAddOngoingFrameDelay() {
        // -- Arrange --
        let dateProvider = TestCurrentDateProvider()
        dateProvider.advance(by: 1)
        let sut = TestDelayedWrapper(keepDelayedFramesDuration: 10, dateProvider: dateProvider)
        let start = dateProvider.systemTime()
        sut.setPreviousFrameSystemTimestamp(SentryDelayedFramesNoFrameInFlight)

        // -- Act --
        dateProvider.advance(by: 5)
        let delay = sut.getFramesDelayObjC(start, endSystemTimestamp: dateProvider.systemTime(), isRunning: true, slowFrameThreshold: 1.0 / 59)

        // -- Assert --
        // The count always includes the frame the tracker adds when it resets.
        XCTAssertEqual(delay.delayDuration, 0, accuracy: 0.0001)
        XCTAssertEqual(delay.framesContributingToDelayCount, 1)
    }

    func testGetFramesDelay_whenFrameInFlight_shouldAddOngoingFrameDelay() {
        // -- Arrange --
        let dateProvider = TestCurrentDateProvider()
        dateProvider.advance(by: 1)
        let sut = TestDelayedWrapper(keepDelayedFramesDuration: 10, dateProvider: dateProvider)
        let start = dateProvider.systemTime()
        sut.setPreviousFrameSystemTimestamp(start)

        // -- Act --
        dateProvider.advance(by: 5)
        let delay = sut.getFramesDelayObjC(start, endSystemTimestamp: dateProvider.systemTime(), isRunning: true, slowFrameThreshold: 1.0 / 59)

        // -- Assert --
        XCTAssertEqual(delay.delayDuration, 5 - 1.0 / 59, accuracy: 0.0001)
        XCTAssertEqual(delay.framesContributingToDelayCount, 2)
    }
}
#endif
