@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class SentryANRTrackerV2Tests: XCTestCase {
    
    private let waitTimeout: TimeInterval = 5.0
    private var timeoutInterval: TimeInterval = 2
        
    private func getSut() throws -> (SentryANRTracker, TestCurrentDateProvider, TestDisplayLinkWrapper, TestSentryCrashWrapper, SentryTestThreadWrapper, SentryFramesTracker) {
        
        let currentDate = TestCurrentDateProvider()
        
        let crashWrapper = TestSentryCrashWrapper.sharedInstance()
        let dispatchQueue = TestSentryDispatchQueueWrapper()
        let threadWrapper = SentryTestThreadWrapper()
        
        let displayLinkWrapper = TestDisplayLinkWrapper(dateProvider: currentDate)
        
        SentryDependencyContainer.sharedInstance().dateProvider = currentDate
        
        let framesTracker = SentryFramesTracker(displayLinkWrapper: displayLinkWrapper, dateProvider: currentDate, dispatchQueueWrapper: dispatchQueue, notificationCenter: TestNSNotificationCenterWrapper(), keepDelayedFramesDuration: 30)
        
        framesTracker.start()
        
        // Add a couple of normal frames, so that querying for frame delay
        // has enough data to not return -1.
        for _ in 0..<1_000 {
            displayLinkWrapper.normalFrame()
        }
        
        return (SentryANRTrackerV2(
            timeoutInterval: timeoutInterval,
            crashWrapper: crashWrapper,
            dispatchQueueWrapper: dispatchQueue,
            threadWrapper: threadWrapper,
            framesTracker: framesTracker) as! SentryANRTracker, currentDate, displayLinkWrapper, crashWrapper, threadWrapper, framesTracker)
    }
    
    /// When no frame gets rendered its a fully blocking app hang.
    ///
    /// [||||--------------]
    /// - means no frame rendered
    /// | means a rendered frame
    func testFullyBlockingAppHang_Reported() throws {
        let (sut, currentDate, displayLinkWrapper, _, _, _) = try getSut()
        defer { sut.clear() }
        
        let listener = SentryANRTrackerV2TestDelegate()
        sut.add(listener: listener)
        
        // The app must hang for slightly over the timeoutInterval to report an app hang
        var advanced = 0.0
        while advanced < timeoutInterval + 0.1 {
            advanced += 0.01
            currentDate.advance(by: 0.01)
        }
        
        wait(for: [listener.anrDetectedExpectation], timeout: timeoutInterval)
        
        renderNormalFramesToStopAppHang(displayLinkWrapper)
        
        for _ in 0..<20 {
            displayLinkWrapper.normalFrame()
        }
        
        wait(for: [listener.anrStoppedExpectation], timeout: waitTimeout)
        
        let actual = try XCTUnwrap(listener.anrStoppedResults.last)
        XCTAssertLessThanOrEqual(2.0, actual.minDuration)
        XCTAssertGreaterThanOrEqual(4.0, actual.maxDuration)
        XCTAssertEqual(0.8, actual.maxDuration - actual.minDuration, accuracy: 0.01)
    }
    
    func testFullyBlockingAppHangWithLargeTimeoutInterval_ReportsCorrectResult() throws {
        timeoutInterval = 5.0
        let (sut, currentDate, displayLinkWrapper, _, _, _) = try getSut()
        defer { sut.clear() }
        
        let listener = SentryANRTrackerV2TestDelegate()
        sut.add(listener: listener)
        
        // The app must hang for slightly over the timeoutInterval to report an app hang
        var advanced = 0.0
        while advanced < timeoutInterval + 0.1 {
            advanced += 0.01
            currentDate.advance(by: 0.01)
        }
        
        wait(for: [listener.anrDetectedExpectation], timeout: timeoutInterval)
        
        renderNormalFramesToStopAppHang(displayLinkWrapper)
        
        for _ in 0..<20 {
            displayLinkWrapper.normalFrame()
        }
        
        wait(for: [listener.anrStoppedExpectation], timeout: waitTimeout)
        
        let actual = try XCTUnwrap(listener.anrStoppedResults.last)
        XCTAssertLessThanOrEqual(5.0, actual.minDuration)
        XCTAssertGreaterThanOrEqual(8.0, actual.maxDuration)
        XCTAssertEqual(2.0, actual.maxDuration - actual.minDuration, accuracy: 0.01)
    }
    
    func testFullyBlockingAppHangWithSmallTimeoutInterval_ReportsCorrectResult() throws {
        timeoutInterval = 0.5
        let (sut, currentDate, displayLinkWrapper, _, _, _) = try getSut()
        defer { sut.clear() }
        
        let listener = SentryANRTrackerV2TestDelegate()
        sut.add(listener: listener)
        
        // The app must hang for slightly over the timeoutInterval to report an app hang
        var advanced = 0.0
        while advanced < timeoutInterval + 0.1 {
            advanced += 0.01
            currentDate.advance(by: 0.01)
        }
        
        wait(for: [listener.anrDetectedExpectation], timeout: timeoutInterval)
        
        renderNormalFramesToStopAppHang(displayLinkWrapper)
        
        for _ in 0..<20 {
            displayLinkWrapper.normalFrame()
        }
        
        wait(for: [listener.anrStoppedExpectation], timeout: waitTimeout)

        let actual = try XCTUnwrap(listener.anrStoppedResults.last)
        XCTAssertLessThanOrEqual(timeoutInterval, actual.minDuration)
        XCTAssertGreaterThanOrEqual(2.0, actual.maxDuration)
        XCTAssertEqual(0.2, actual.maxDuration - actual.minDuration, accuracy: 0.01)
    }
    
    /// For a non fully blocking app hang at least one frame must be rendered during the hang.
    ///
    /// [||||------|--------]
    /// - means no frame rendered
    /// | means a rendered frame
    func testNonFullyBlockingAppHang_Reported() throws {
        let (sut, _, displayLinkWrapper, _, _, _) = try getSut()
        defer { sut.clear() }
        
        let listener = SentryANRTrackerV2TestDelegate()
        
        sut.add(listener: listener)
    
        triggerNonFullyBlockingAppHang(displayLinkWrapper)
        
        wait(for: [listener.anrDetectedExpectation], timeout: waitTimeout)
        XCTAssertEqual(listener.anrsDetected.last, .nonFullyBlocking)
        
        renderNormalFramesToStopAppHang(displayLinkWrapper)
        
        wait(for: [listener.anrStoppedExpectation], timeout: waitTimeout)
        
        let actual = try XCTUnwrap(listener.anrStoppedResults.last)
        XCTAssertLessThanOrEqual(2.0, actual.minDuration)
        XCTAssertGreaterThanOrEqual(4.0, actual.maxDuration)
        XCTAssertEqual(0.8, actual.maxDuration - actual.minDuration, accuracy: 0.01)
    }
    
    /// 3 frozen frames aren't enough for a non fully blocking app hang.
    ///
    /// [||||---|------|-----]
    /// - means no frame rendered
    /// | means a rendered frame
    func testAlmostNonFullyBlockingAppHang_NoneReported() throws {
        let (sut, _, displayLinkWrapper, _, _, _) = try getSut()
        defer { sut.clear() }
        
        let listener = SentryANRTrackerV2TestDelegate(shouldANRBeDetected: false, shouldStoppedBeCalled: false)
        
        sut.add(listener: listener)
        
        displayLinkWrapper.frameWith(delay: 0.7)
        displayLinkWrapper.frameWith(delay: 0.7)
        displayLinkWrapper.frameWith(delay: 0.7)
        
        wait(for: [listener.anrDetectedExpectation], timeout: waitTimeout)
        
        renderNormalFramesToStopAppHang(displayLinkWrapper)
        
        wait(for: [listener.anrStoppedExpectation], timeout: waitTimeout)
    }
    
    /// [||||------------]
    /// - means no frame rendered
    /// | means a rendered frame
    func testAlmostFullyBlockingAppHang_NoneReported() throws {
        let (sut, dateProvider, displayLinkWrapper, _, _, _) = try getSut()
        defer { sut.clear() }
        
        let listener = SentryANRTrackerV2TestDelegate(shouldANRBeDetected: false, shouldStoppedBeCalled: false)
        
        sut.add(listener: listener)
        
        for _ in 0..<100 {
            displayLinkWrapper.normalFrame()
        }
        // The app must hang for slightly over the timeoutInterval to report an app hang
        dateProvider.advance(by: timeoutInterval - 0.1)
        
        wait(for: [listener.anrDetectedExpectation], timeout: waitTimeout)
        
        renderNormalFramesToStopAppHang(displayLinkWrapper)
        
        wait(for: [listener.anrStoppedExpectation], timeout: waitTimeout)
    }
    
    /// One fully blocking app hang followed by non fully blocking
    ///
    /// [||||-----------------|--------]
    /// - means no frame rendered
    /// | means a rendered frame
    func testFullyBlockingFollowedByNonFullyBlocking_OnlyFirstReported() throws {
        let (sut, dateProvider, displayLinkWrapper, _, _, _) = try getSut()
        defer { sut.clear() }
        
        let listener = SentryANRTrackerV2TestDelegate()
        
        sut.add(listener: listener)
        
        triggerFullyBlockingAppHang(dateProvider)
        
        wait(for: [listener.anrDetectedExpectation], timeout: waitTimeout)
        
        triggerNonFullyBlockingAppHang(displayLinkWrapper)
        
        renderNormalFramesToStopAppHang(displayLinkWrapper)
        
        wait(for: [listener.anrStoppedExpectation], timeout: waitTimeout)

        let actual = try XCTUnwrap(listener.anrStoppedResults.last)
        XCTAssertLessThanOrEqual(4.0, actual.minDuration)
        XCTAssertGreaterThanOrEqual(6.0, actual.maxDuration)
        XCTAssertEqual(0.8, actual.maxDuration - actual.minDuration, accuracy: 0.01)
    }
    
    /// Fully blocking app hang, app hang stops, again fully blocking app hang
    ///
    /// [||||-----------------||||||||---------------]
    /// - means no frame rendered
    /// | means a rendered frame
    func testFullyBlockingFollowedByFullyBlocking_BothReported() throws {
        let (sut, currentDate, displayLinkWrapper, _, _, _) = try getSut()
        defer { sut.clear() }
        
        // We use multiple listeners here, because we can't reset the XCTestExpectation
        let firstListener = SentryANRTrackerV2TestDelegate()
        firstListener.anrDetectedExpectation.expectedFulfillmentCount = 2
        firstListener.anrStoppedExpectation.expectedFulfillmentCount = 2
        sut.add(listener: firstListener)
        
        let secondListener = SentryANRTrackerV2TestDelegate()
        secondListener.anrDetectedExpectation.assertForOverFulfill = false
        secondListener.anrStoppedExpectation.assertForOverFulfill = false
        sut.add(listener: secondListener)
        
        triggerFullyBlockingAppHang(currentDate)
        
        wait(for: [secondListener.anrDetectedExpectation], timeout: waitTimeout)
        
        renderNormalFramesToStopAppHang(displayLinkWrapper)
        
        wait(for: [secondListener.anrStoppedExpectation], timeout: waitTimeout)
        
        let thirdListener = SentryANRTrackerV2TestDelegate()
        sut.add(listener: thirdListener)
        
        triggerFullyBlockingAppHang(currentDate)
        
        wait(for: [thirdListener.anrDetectedExpectation], timeout: waitTimeout)
        
        renderNormalFramesToStopAppHang(displayLinkWrapper)
        
        wait(for: [thirdListener.anrStoppedExpectation], timeout: waitTimeout)
        
        wait(for: [firstListener.anrDetectedExpectation, firstListener.anrStoppedExpectation], timeout: waitTimeout)
    }
    
    /// Long fully blocking app hang, app hang stops, no non fully blocking gets falsely reported
    ///
    /// [||||--------------------------------------|||||||]
    /// - means no frame rendered
    /// | means a rendered frame
    func testFullyBlockingFollowedByNormalFrames_OneReported() throws {
        let (sut, currentDate, displayLinkWrapper, _, _, _) = try getSut()
        defer { sut.clear() }
        
        let firstListener = SentryANRTrackerV2TestDelegate()
        sut.add(listener: firstListener)
        
        let secondListener = SentryANRTrackerV2TestDelegate()
        sut.add(listener: secondListener)
        
        triggerFullyBlockingAppHang(currentDate)
        
        wait(for: [secondListener.anrDetectedExpectation], timeout: waitTimeout)
        
        let thirdListener = SentryANRTrackerV2TestDelegate(shouldANRBeDetected: false)
        sut.add(listener: thirdListener)
        
        renderNormalFramesToStopAppHang(displayLinkWrapper)

        wait(for: [firstListener.anrDetectedExpectation, firstListener.anrStoppedExpectation, thirdListener.anrStoppedExpectation, thirdListener.anrDetectedExpectation], timeout: waitTimeout)

        let firstActual = try XCTUnwrap(firstListener.anrStoppedResults.last)
        XCTAssertGreaterThanOrEqual(firstActual.minDuration, 2.0, "minDuration should be greater than or equal to 2.0")
        XCTAssertLessThanOrEqual(firstActual.maxDuration, 5.0, "maxDuration should be less than or equal to 5.0")
        XCTAssertEqual(0.8, firstActual.maxDuration - firstActual.minDuration, accuracy: 0.01)

        let secondActual = try XCTUnwrap(secondListener.anrStoppedResults.last)
        XCTAssertGreaterThanOrEqual(secondActual.minDuration, 2.0, "minDuration should be greater than or equal to 2.0")
        XCTAssertLessThanOrEqual(secondActual.maxDuration, 5.0, "maxDuration should be less than or equal to 5.0")
        XCTAssertEqual(0.8, secondActual.maxDuration - secondActual.minDuration, accuracy: 0.01)

        let thirdActual = try XCTUnwrap(thirdListener.anrStoppedResults.last)
        XCTAssertGreaterThanOrEqual(thirdActual.minDuration, 2.0, "minDuration should be greater than or equal to 2.0")
        XCTAssertLessThanOrEqual(thirdActual.maxDuration, 5.0, "maxDuration should be less than or equal to 5.0")
        XCTAssertEqual(0.8, thirdActual.maxDuration - thirdActual.minDuration, accuracy: 0.01)
    }
    
    func testTwoListeners_FullyBlocking_ReportedToBothListeners() throws {
        let (sut, currentDate, displayLinkWrapper, _, _, _) = try getSut()
        defer { sut.clear() }
        
        let firstListener = SentryANRTrackerV2TestDelegate()
        
        sut.add(listener: firstListener)
        
        let secondListener = SentryANRTrackerV2TestDelegate()
        sut.add(listener: secondListener)
        
        triggerFullyBlockingAppHang(currentDate)
        
        wait(for: [firstListener.anrDetectedExpectation, secondListener.anrDetectedExpectation], timeout: waitTimeout)
        
        renderNormalFramesToStopAppHang(displayLinkWrapper)
        
        wait(for: [firstListener.anrStoppedExpectation, secondListener.anrStoppedExpectation], timeout: waitTimeout)
    }
    
    func testFullyBlockingAppHang_ButAppInBackground_NoneReported() throws {
        let (sut, currentDate, displayLinkWrapper, crashWrapper, _, _) = try getSut()
        defer { sut.clear() }
        
        crashWrapper.internalIsApplicationInForeground = false
        
        let listener = SentryANRTrackerV2TestDelegate(shouldANRBeDetected: false, shouldStoppedBeCalled: false)
        
        sut.add(listener: listener)
        
        triggerFullyBlockingAppHang(currentDate)
        
        renderNormalFramesToStopAppHang(displayLinkWrapper)

        wait(for: [listener.anrDetectedExpectation, listener.anrStoppedExpectation], timeout: waitTimeout)
    }
    
    func testAppSuspended_NoAppHang() throws {
        let (sut, currentDate, _, _, threadWrapper, _) = try getSut()
        defer { sut.clear() }
        
        let listener = SentryANRTrackerV2TestDelegate(shouldANRBeDetected: false, shouldStoppedBeCalled: false)
        
        // When the app is suspended the thread sleep can take way longer
        // than expected.
        threadWrapper.blockWhenSleeping = {
            let delta = self.timeoutInterval * 2
            
            currentDate.setDate(date: currentDate.date().addingTimeInterval(delta))
        }
        
        sut.add(listener: listener)
        
        triggerFullyBlockingAppHang(currentDate)

        wait(for: [listener.anrDetectedExpectation, listener.anrStoppedExpectation], timeout: waitTimeout)
    }
    
    func testRemoveListener_StopsReporting() throws {
        let (sut, currentDate, _, _, threadWrapper, _) = try getSut()
        defer { sut.clear() }
        
        let listener = SentryANRTrackerV2TestDelegate(shouldANRBeDetected: false, shouldStoppedBeCalled: false)
        
        let mainBlockExpectation = expectation(description: "Main Block")
        
        threadWrapper.blockWhenSleeping = {
            sut.remove(listener: listener)
            mainBlockExpectation.fulfill()
        }
        
        triggerFullyBlockingAppHang(currentDate)
        
        sut.add(listener: listener)
        
        wait(for: [listener.anrDetectedExpectation, listener.anrStoppedExpectation, mainBlockExpectation], timeout: waitTimeout)
    }
    
    func testClear_StopsReporting() throws {
        let (sut, currentDate, _, _, threadWrapper, _) = try getSut()
        defer { sut.clear() }
        
        let firstListener = SentryANRTrackerV2TestDelegate(shouldANRBeDetected: false, shouldStoppedBeCalled: false)
        let secondListener = SentryANRTrackerV2TestDelegate(shouldANRBeDetected: false, shouldStoppedBeCalled: false)
        
        let mainBlockExpectation = expectation(description: "Main Block")
        
        //Having a second Listener may cause the tracker to execute more than once before the end of the test
        mainBlockExpectation.assertForOverFulfill = false
        
        threadWrapper.blockWhenSleeping = {
            sut.clear()
            mainBlockExpectation.fulfill()
        }
        
        sut.add(listener: secondListener)
        sut.add(listener: firstListener)
        
        triggerFullyBlockingAppHang(currentDate)
        
        wait(for: [firstListener.anrDetectedExpectation, firstListener.anrStoppedExpectation, mainBlockExpectation, secondListener.anrStoppedExpectation, secondListener.anrDetectedExpectation], timeout: waitTimeout)
    }
    
    func testNotRemovingDeallocatedListener_DoesNotRetainListener_AndStopsTracking() throws {
        let (sut, currentDate, _, _, _, _) = try getSut()
        defer { sut.clear() }
        
        let listener = SentryANRTrackerV2TestDelegate(shouldANRBeDetected: false, shouldStoppedBeCalled: false)
        
        // So ARC deallocates SentryANRTrackerTestDelegate
        let addListenersCount = 10
        func addListeners() {
            for _ in 0..<addListenersCount {
                sut.add(listener: SentryANRTrackerV2TestDelegate())
            }
        }
        addListeners()
        
        sut.add(listener: listener)
        sut.remove(listener: listener)
        
        triggerFullyBlockingAppHang(currentDate)
        
        let listeners = Dynamic(sut).listeners.asObject as? NSHashTable<NSObject>
        
        XCTAssertGreaterThan(addListenersCount, listeners?.count ?? addListenersCount)
        
        wait(for: [listener.anrDetectedExpectation, listener.anrStoppedExpectation], timeout: self.waitTimeout)
    }
    
    func testClearStopsThread() throws {
        let (sut, _, _, _, threadWrapper, _) = try getSut()
        
        sut.add(listener: SentryANRTrackerV2TestDelegate())
        
        sut.clear()
        
        wait(for: [threadWrapper.threadFinishedExpectation], timeout: 5)
        XCTAssertEqual(0, threadWrapper.threads.count)
    }
    
    func testClearDirectlyAfterStart_FullyBlocking_NotReported() throws {
        let (sut, currentDate, _, _, threadWrapper, _) = try getSut()
        defer { sut.clear() }
        
        let listener = SentryANRTrackerV2TestDelegate(shouldANRBeDetected: false, shouldStoppedBeCalled: false)
        
        let invocations = 10
        for _ in 0..<invocations {
            sut.add(listener: listener)
            sut.clear()
        }
        
        triggerFullyBlockingAppHang(currentDate)
        
        wait(for: [listener.anrDetectedExpectation, listener.anrStoppedExpectation], timeout: self.waitTimeout)
        
        XCTAssertEqual(0, threadWrapper.threads.count)        
        // As it can take a while until a new thread is started, the thread tracker may start
        // and finish multiple times. Most importantly, the code covers every start with one finish.
        XCTAssertEqual(threadWrapper.threadStartedInvocations.count, threadWrapper.threadFinishedInvocations.count, "The number of started and finished threads should be equal, otherwise the ANR tracker could run.")
    }
    
    func testNoFrameDelayData_FullyBlocking_NotReported() throws {
        let (sut, currentDate, _, _, _, framesTracker) = try getSut()
        defer { sut.clear() }
        
        framesTracker.stop()
        
        let listener = SentryANRTrackerV2TestDelegate(shouldANRBeDetected: false, shouldStoppedBeCalled: false)
        
        sut.add(listener: listener)
        
        triggerFullyBlockingAppHang(currentDate)
        
        wait(for: [listener.anrDetectedExpectation, listener.anrStoppedExpectation], timeout: waitTimeout)
    }
    
    private func renderNormalFramesToStopAppHang(_ displayLinkWrapper: TestDisplayLinkWrapper) {
        
        // We need to render normal frames until we reach the
        // required healthy non frames delay threshold for the tracker to
        // mark the app hang as stopped
        let requiredNormalFrameDuration = timeoutInterval / 5 * 2 * 0.80 + displayLinkWrapper.currentFrameRate.tickDuration
        
        var advanced = 0.0
        while advanced <= requiredNormalFrameDuration {
            advanced += displayLinkWrapper.currentFrameRate.tickDuration
            displayLinkWrapper.normalFrame()
        }
    }
    
    private func triggerFullyBlockingAppHang(_ currentDate: TestCurrentDateProvider) {
        // The app must hang for slightly over the timeoutInterval to report an app hang
        var advanced = 0.0
        while advanced < timeoutInterval + 0.1 {
            advanced += 0.01
            currentDate.advance(by: 0.01)
        }
    }
    
    private func triggerNonFullyBlockingAppHang(_ displayLinkWrapper: TestDisplayLinkWrapper) {
        displayLinkWrapper.frameWith(delay: 1.0)
        displayLinkWrapper.frameWith(delay: 1.0)
    }
    
}

class SentryANRTrackerV2TestDelegate: NSObject, SentryANRTrackerDelegate {
    
    let anrDetectedExpectation = XCTestExpectation(description: "Test Delegate ANR Detection")
    let anrStoppedExpectation  = XCTestExpectation(description: "Test Delegate ANR Stopped")
    let anrsDetected = Invocations<Sentry.SentryANRType>()
    let anrStoppedResults = Invocations<SentryANRStoppedResult>()
    
    init(shouldANRBeDetected: Bool = true, shouldStoppedBeCalled: Bool = true) {
        if !shouldANRBeDetected {
            anrDetectedExpectation.isInverted = true
        }
        
        if !shouldStoppedBeCalled {
            anrStoppedExpectation.isInverted = true
        }
        
        anrDetectedExpectation.assertForOverFulfill = true
        anrStoppedExpectation.assertForOverFulfill = true
    }
    
    func anrStopped(result: SentryANRStoppedResult?) {
        guard let nonNilResult = result else {
            XCTFail("ANRStopped result is nil")
            return
        }
        
        anrStoppedResults.record(nonNilResult)
        
        anrStoppedExpectation.fulfill()
    }
    
    func anrDetected(type: Sentry.SentryANRType) {
        anrsDetected.record(type)
        anrDetectedExpectation.fulfill()
    }
}

#endif
