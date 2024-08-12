@testable import Sentry
import SentryTestUtils
import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class SentryANRTrackerV2Tests: XCTestCase {
    
    private let waitTimeout: TimeInterval = 1.0
    private let timeoutInterval: TimeInterval = 2
        
    private func getSut() throws -> (SentryANRTrackerV2, TestCurrentDateProvider, TestDisplayLinkWrapper, TestSentryCrashWrapper, SentryTestThreadWrapper) {
        
        let currentDate = TestCurrentDateProvider()
        let crashWrapper = TestSentryCrashWrapper.sharedInstance()
        let dispatchQueue = TestSentryDispatchQueueWrapper()
        let threadWrapper = SentryTestThreadWrapper()
    
        threadWrapper.blockWhenSleeping = {
            Thread.sleep(forTimeInterval: 0.1)
        }
        
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
            framesTracker: framesTracker), currentDate, displayLinkWrapper, crashWrapper, threadWrapper)
    }
    
    override func setUp() {
        super.setUp()
        
        // To avoid spamming the test logs
        SentryLog.configure(true, diagnosticLevel: .debug)
    }
    
    override func tearDown() {
        super.tearDown()
        
        SentryLog.setTestDefaultLogLevel()
    }
    
    /// When no frame gets rendered its a fully blocking app hang.
    ///
    /// [||||--------------]
    /// - means no frame rendered
    /// | means a rendered frame
    func testFullyBlockingAppHang_Reported() throws {
        let (sut, currentDate, displayLinkWrapper, _, _) = try getSut()
        defer { sut.clear() }
        
        let listener = SentryANRTrackerV2TestDelegate()
        sut.addListener(listener)
        
        // The app must hang for slightly over the timeoutInterval to report an app hang
        var advanced = 0.0
        while advanced < timeoutInterval + 0.1 {
            advanced += 0.01
            currentDate.advance(by: 0.01)
        }
        
        wait(for: [listener.anrDetectedExpectation], timeout: waitTimeout)
        XCTAssertEqual(SentryANRType.fullyBlocking, listener.lastANRDetectedType)
        
        // Render normal frames to stop the app hang
        for _ in 0..<120 {
            displayLinkWrapper.normalFrame()
        }
        
        wait(for: [listener.anrStoppedExpectation], timeout: waitTimeout)
    }
    
    /// For a non fully blocking app hang at least one frame must be rendered during the hang.
    ///
    /// [||||------|--------]
    /// - means no frame rendered
    /// | means a rendered frame
    func testNonFullyBlockingAppHang_Reported() throws {
        let (sut, _, displayLinkWrapper, _, _) = try getSut()
        defer { sut.clear() }
        
        let listener = SentryANRTrackerV2TestDelegate()
        
        sut.addListener(listener)
        
        for _ in 0..<100 {
            displayLinkWrapper.normalFrame()
        }
        displayLinkWrapper.frameWith(delay: 1.0)
        displayLinkWrapper.normalFrame()
        displayLinkWrapper.frameWith(delay: 0.81)
        
        wait(for: [listener.anrDetectedExpectation], timeout: waitTimeout)
        XCTAssertEqual(SentryANRType.nonFullyBlocking, listener.lastANRDetectedType)
        
        // Render normal frames to stop the app hang
        for _ in 0..<120 {
            displayLinkWrapper.normalFrame()
        }
        
        wait(for: [listener.anrStoppedExpectation], timeout: waitTimeout)
    }
    
    /// No frame is rendered during the blocking time otherwise it would be a non fully blocking app hang.
    /// We accept the tradeoff of maybe not reporting long enough fully blocking app hangs so we report
    /// fully blocking app hangs correctly.
    ///
    /// [||||--------------]
    /// - means no frame rendered
    /// | means a rendered frame
    func testAlmostFullyBlockingAppHang_NoneReported() throws {
        let (sut, dateProvider, displayLinkWrapper, _, _) = try getSut()
        defer { sut.clear() }
        
        let listener = SentryANRTrackerV2TestDelegate(shouldANRBeDetected: false, shouldStoppedBeCalled: false)
        
        sut.addListener(listener)
        
        for _ in 0..<100 {
            displayLinkWrapper.normalFrame()
        }
        // The app must hang for slightly over the timeoutInterval to report an app hang
        dateProvider.advance(by: timeoutInterval)
        
        wait(for: [listener.anrDetectedExpectation], timeout: waitTimeout)
        
        for _ in 0..<100 {
            displayLinkWrapper.normalFrame()
        }
        
        wait(for: [listener.anrStoppedExpectation], timeout: waitTimeout)
    }
    
    /// One non fully blocking app hang followed by blocking
    ///
    /// [||||-----|--------------------]
    /// - means no frame rendered
    /// | means a rendered frame
    func testNonFullyBlockingFollowedByFullyBlocking_OnlyFirstReported() throws {
        let (sut, dateProvider, displayLinkWrapper, _, threadWrapper) = try getSut()
        defer { sut.clear() }
        
        let listener = SentryANRTrackerV2TestDelegate()
        
        sut.addListener(listener)
        
        for _ in 0..<120 {
            displayLinkWrapper.normalFrame()
        }
        
        dateProvider.advance(by: 1.0)
        displayLinkWrapper.normalFrame()
        dateProvider.advance(by: 1.0)
        
        threadWrapper.blockWhenSleeping = {
            dateProvider.advance(by: 0.1)
        }
        
        wait(for: [listener.anrDetectedExpectation], timeout: waitTimeout)
        XCTAssertEqual(SentryANRType.nonFullyBlocking, listener.lastANRDetectedType)
        
        threadWrapper.blockWhenSleeping = {}
        
        for _ in 0..<120 {
            displayLinkWrapper.normalFrame()
        }
        
        wait(for: [listener.anrStoppedExpectation], timeout: waitTimeout)
    }
    
    /// One fully blocking app hang followed by non fully blocking
    ///
    /// [||||-----------------|--------]
    /// - means no frame rendered
    /// | means a rendered frame
    func testFullyBlockingFollowedByNonFullyBlocking_OnlyFirstReported() throws {
        let (sut, dateProvider, displayLinkWrapper, _, _) = try getSut()
        defer { sut.clear() }
        
        let listener = SentryANRTrackerV2TestDelegate()
        
        sut.addListener(listener)
        
        for _ in 0..<120 {
            displayLinkWrapper.normalFrame()
        }
        
        for _ in 0..<120 {
            displayLinkWrapper.normalFrame()
        }
        dateProvider.advance(by: 2.1)
        
        wait(for: [listener.anrDetectedExpectation], timeout: waitTimeout)
        XCTAssertEqual(SentryANRType.fullyBlocking, listener.lastANRDetectedType)
        
        displayLinkWrapper.normalFrame()
        dateProvider.advance(by: 1.0)
        displayLinkWrapper.normalFrame()
        dateProvider.advance(by: 1.0)
        
        for _ in 0..<120 {
            displayLinkWrapper.normalFrame()
        }
        
        wait(for: [listener.anrStoppedExpectation], timeout: waitTimeout)
    }
    
    /// Fully blocking app hang, app hang stops, again fully blocking app hang
    ///
    /// [||||-----------------||||||||---------------]
    /// - means no frame rendered
    /// | means a rendered frame
    func testFullyBlockingFollowedByFullyBlocking_BothReported() throws {
        let (sut, currentDate, displayLinkWrapper, _, _) = try getSut()
        defer { sut.clear() }
        
        let firstListener = SentryANRTrackerV2TestDelegate()
        firstListener.anrDetectedExpectation.expectedFulfillmentCount = 2
        firstListener.anrStoppedExpectation.expectedFulfillmentCount = 2
        sut.addListener(firstListener)
        
        let secondListener = SentryANRTrackerV2TestDelegate()
        secondListener.anrDetectedExpectation.assertForOverFulfill = false
        secondListener.anrStoppedExpectation.assertForOverFulfill = false
        sut.addListener(secondListener)
        
        // The app must hang for slightly over the timeoutInterval to report an app hang
        var advanced = 0.0
        while advanced < timeoutInterval + 0.1 {
            advanced += 0.01
            currentDate.advance(by: 0.01)
        }
        
        wait(for: [secondListener.anrDetectedExpectation], timeout: waitTimeout)
        XCTAssertEqual(SentryANRType.fullyBlocking, secondListener.lastANRDetectedType)
        
        for _ in 0..<120 {
            displayLinkWrapper.normalFrame()
        }
        
        wait(for: [secondListener.anrStoppedExpectation], timeout: waitTimeout)
        
        let thirdListener = SentryANRTrackerV2TestDelegate()
        sut.addListener(thirdListener)
        
        // The app must hang for slightly over the timeoutInterval to report an app hang
        advanced = 0.0
        while advanced < timeoutInterval + 0.1 {
            advanced += 0.01
            currentDate.advance(by: 0.01)
        }
        
        wait(for: [thirdListener.anrDetectedExpectation], timeout: waitTimeout)
        XCTAssertEqual(SentryANRType.fullyBlocking, thirdListener.lastANRDetectedType)
        
        for _ in 0..<120 {
            displayLinkWrapper.normalFrame()
        }
        
        wait(for: [thirdListener.anrStoppedExpectation], timeout: waitTimeout)
        
        wait(for: [firstListener.anrDetectedExpectation, firstListener.anrStoppedExpectation], timeout: 5.0)
        XCTAssertEqual(SentryANRType.fullyBlocking, firstListener.lastANRDetectedType)
    }
    
    /// Long fully blocking app hang, app hang stops, no non fully blocking gets falsely reported
    ///
    /// [||||--------------------------------------|||||||]
    /// - means no frame rendered
    /// | means a rendered frame
    func testFullyBlockingFollowedByNormalFrames_OneReported() throws {
        let (sut, currentDate, displayLinkWrapper, _, _) = try getSut()
        defer { sut.clear() }
        
        let firstListener = SentryANRTrackerV2TestDelegate()
        sut.addListener(firstListener)
        
        let secondListener = SentryANRTrackerV2TestDelegate()
        sut.addListener(secondListener)
        
        // The app must hang for slightly over the timeoutInterval to report an app hang
        var advanced = 0.0
        while advanced < timeoutInterval * 3 {
            advanced += 0.01
            currentDate.advance(by: 0.01)
        }
        
        wait(for: [secondListener.anrDetectedExpectation], timeout: waitTimeout)
        XCTAssertEqual(SentryANRType.fullyBlocking, secondListener.lastANRDetectedType)
        
        let thirdListener = SentryANRTrackerV2TestDelegate(shouldANRBeDetected: false)
        sut.addListener(thirdListener)
        
        for _ in 0..<120 {
            displayLinkWrapper.normalFrame()
        }
        
        wait(for: [secondListener.anrStoppedExpectation], timeout: waitTimeout)
        
        for _ in 0..<5 {
            displayLinkWrapper.normalFrame()
            currentDate.advance(by: 0.1)
        }
        
        wait(for: [firstListener.anrDetectedExpectation, firstListener.anrStoppedExpectation, thirdListener.anrStoppedExpectation, thirdListener.anrDetectedExpectation], timeout: waitTimeout)
        XCTAssertEqual(SentryANRType.fullyBlocking, firstListener.lastANRDetectedType)
    }
    
    func testAlmostNonFullyBlockingAppHang_NoneReported() throws {
        let (sut, _, displayLinkWrapper, _, _) = try getSut()
        defer { sut.clear() }
        
        let listener = SentryANRTrackerV2TestDelegate(shouldANRBeDetected: false, shouldStoppedBeCalled: false)
        
        sut.addListener(listener)
        
        for _ in 0..<100 {
            displayLinkWrapper.normalFrame()
        }
        displayLinkWrapper.frameWith(delay: 1.8)
        for _ in 0..<10 {
            displayLinkWrapper.normalFrame()
        }
        
        wait(for: [listener.anrDetectedExpectation, listener.anrStoppedExpectation], timeout: waitTimeout)
    }
    
    func testAlmostFullyBlockingAppHang_NotReported() throws {
        let (sut, currentDate, displayLinkWrapper, _, _) = try getSut()
        defer { sut.clear() }
        
        let listener = SentryANRTrackerV2TestDelegate(shouldANRBeDetected: false, shouldStoppedBeCalled: false)
        
        sut.addListener(listener)
        
        for _ in 0..<100 {
            displayLinkWrapper.normalFrame()
        }
        var advanced = 0.0
        while advanced < 1.99 {
            advanced += 0.01
            currentDate.advance(by: 0.01)
        }
        
        wait(for: [listener.anrDetectedExpectation, listener.anrStoppedExpectation], timeout: waitTimeout)
    }
    
    func testMultipleListeners() throws {
        let (sut, currentDate, displayLinkWrapper, _, _) = try getSut()
        defer { sut.clear() }
        
        let firstListener = SentryANRTrackerV2TestDelegate()
        
        sut.addListener(firstListener)
        
        let secondListener = SentryANRTrackerV2TestDelegate()
        sut.addListener(secondListener)
        
        // The app must hang for slightly over the timeoutInterval to report an app hang
        var advanced = 0.0
        while advanced < timeoutInterval + 0.1 {
            advanced += 0.01
            currentDate.advance(by: 0.01)
        }
        
        wait(for: [firstListener.anrDetectedExpectation, secondListener.anrDetectedExpectation], timeout: waitTimeout)
        
        XCTAssertEqual(SentryANRType.fullyBlocking, firstListener.lastANRDetectedType)
        XCTAssertEqual(SentryANRType.fullyBlocking, secondListener.lastANRDetectedType)
        
        for _ in 0..<120 {
            displayLinkWrapper.normalFrame()
        }
        
        wait(for: [firstListener.anrStoppedExpectation, secondListener.anrStoppedExpectation], timeout: waitTimeout)
    }
    
    func testFullyBlockingANR_ButAppInBackground_NoANRReported() throws {
        let (sut, currentDate, _, crashWrapper, _) = try getSut()
        defer { sut.clear() }
        
        crashWrapper.internalIsApplicationInForeground = false
        
        let listener = SentryANRTrackerV2TestDelegate(shouldANRBeDetected: false, shouldStoppedBeCalled: false)
        
        sut.addListener(listener)
        
        // The app must hang for slightly over the timeoutInterval to report an app hang
        var advanced = 0.0
        while advanced < timeoutInterval + 0.1 {
            advanced += 0.01
            currentDate.advance(by: 0.01)
        }
        
        wait(for: [listener.anrDetectedExpectation, listener.anrStoppedExpectation], timeout: waitTimeout)
    }
    
    func testNonFullyBlockingANR_ButAppInBackground_NoANRReported() throws {
        let (sut, _, displayLinkWrapper, crashWrapper, _) = try getSut()
        defer { sut.clear() }
        
        crashWrapper.internalIsApplicationInForeground = false
        
        let listener = SentryANRTrackerV2TestDelegate(shouldANRBeDetected: false, shouldStoppedBeCalled: false)
        
        sut.addListener(listener)
        
        for _ in 0..<10 {
            _ = displayLinkWrapper.fastestFrozenFrame()
        }
        
        wait(for: [listener.anrDetectedExpectation, listener.anrStoppedExpectation], timeout: waitTimeout)
    }
    
    func testMultipleANRs_MultipleReported() throws {
        let (sut, currentDate, displayLinkWrapper, _, _) = try getSut()
        defer { sut.clear() }
        
        let firstListener = SentryANRTrackerV2TestDelegate()
        sut.addListener(firstListener)
        
        let secondListener = SentryANRTrackerV2TestDelegate()
        sut.addListener(secondListener)
    
        // The app must hang for slightly over the timeoutInterval to report an app hang
        var advanced = 0.0
        while advanced < timeoutInterval + 0.1 {
            advanced += 0.01
            currentDate.advance(by: 0.01)
        }
        
        wait(for: [firstListener.anrDetectedExpectation, secondListener.anrDetectedExpectation], timeout: waitTimeout)
        
        for _ in 0..<120 {
            displayLinkWrapper.normalFrame()
        }
        
        wait(for: [firstListener.anrStoppedExpectation, secondListener.anrStoppedExpectation], timeout: waitTimeout)
    }
    
    func testAppSuspended_NoANR() throws {
        let (sut, currentDate, displayLinkWrapper, _, threadWrapper) = try getSut()
        defer { sut.clear() }
        
        let listener = SentryANRTrackerV2TestDelegate(shouldANRBeDetected: false, shouldStoppedBeCalled: false)
        
        for _ in 0..<10 {
            _ = displayLinkWrapper.fastestFrozenFrame()
        }
        
        threadWrapper.blockWhenSleeping = {
            let delta = self.timeoutInterval * 2
            
            currentDate.setDate(date: currentDate.date().addingTimeInterval(delta))
        }
        
        sut.addListener(listener)
        
        wait(for: [listener.anrDetectedExpectation, listener.anrStoppedExpectation], timeout: waitTimeout)
    }
    
    func testRemoveListener_StopsReportingANRs() throws {
        let (sut, _, displayLinkWrapper, _, threadWrapper) = try getSut()
        defer { sut.clear() }
        
        let listener = SentryANRTrackerV2TestDelegate(shouldANRBeDetected: false, shouldStoppedBeCalled: false)
        
        let mainBlockExpectation = expectation(description: "Main Block")
        
        threadWrapper.blockWhenSleeping = {
            sut.removeListener(listener)
            mainBlockExpectation.fulfill()
        }
        
        displayLinkWrapper.frameWith(delay: 10.0)
        
        sut.addListener(listener)
        
        wait(for: [listener.anrDetectedExpectation, listener.anrStoppedExpectation, mainBlockExpectation], timeout: waitTimeout)
    }
    
    func testClear_StopsReportingANRs() throws {
        let (sut, _, _, _, threadWrapper) = try getSut()
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
        
        sut.addListener(secondListener)
        sut.addListener(firstListener)
        
        wait(for: [firstListener.anrDetectedExpectation, firstListener.anrStoppedExpectation, mainBlockExpectation, secondListener.anrStoppedExpectation, secondListener.anrDetectedExpectation], timeout: waitTimeout)
    }
    
    func testNotRemovingDeallocatedListener_DoesNotRetainListener_AndStopsTracking() throws {
        let (sut, _, _, _, _) = try getSut()
        defer { sut.clear() }
        
        let listener = SentryANRTrackerV2TestDelegate(shouldANRBeDetected: false, shouldStoppedBeCalled: false)
        
        // So ARC deallocates SentryANRTrackerTestDelegate
        let addListenersCount = 10
        func addListeners() {
            for _ in 0..<addListenersCount {
                sut.addListener(SentryANRTrackerV2TestDelegate())
            }
        }
        addListeners()
        
        sut.addListener(listener)
        sut.removeListener(listener)
        
        let listeners = Dynamic(sut).listeners.asObject as? NSHashTable<NSObject>
        
        XCTAssertGreaterThan(addListenersCount, listeners?.count ?? addListenersCount)
        
        wait(for: [listener.anrDetectedExpectation, listener.anrStoppedExpectation], timeout: self.waitTimeout)
    }
    
    func testClearStopsThread() throws {
        let (sut, _, _, _, threadWrapper) = try getSut()
        
        sut.addListener(SentryANRTrackerV2TestDelegate())
        
        sut.clear()
        
        wait(for: [threadWrapper.threadFinishedExpectation], timeout: 5)
        XCTAssertEqual(0, threadWrapper.threads.count)
    }
    
    func testClearDirectlyAfterStart() throws {
        let (sut, _, displayLinkWrapper, _, threadWrapper) = try getSut()
        defer { sut.clear() }
        
        let listener = SentryANRTrackerV2TestDelegate(shouldANRBeDetected: false, shouldStoppedBeCalled: false)
        
        displayLinkWrapper.frameWith(delay: timeoutInterval * 2)
        
        let invocations = 10
        for _ in 0..<invocations {
            sut.addListener(listener)
            sut.clear()
        }
        
        wait(for: [listener.anrDetectedExpectation, listener.anrStoppedExpectation], timeout: self.waitTimeout)
        
        XCTAssertEqual(0, threadWrapper.threads.count)
        XCTAssertEqual(1, threadWrapper.threadStartedInvocations.count)
        XCTAssertEqual(1, threadWrapper.threadFinishedInvocations.count)
    }
}

class SentryANRTrackerV2TestDelegate: NSObject, SentryANRTrackerV2Delegate {
    
    let anrDetectedExpectation = XCTestExpectation(description: "Test Delegate ANR Detection")
    let anrStoppedExpectation  = XCTestExpectation(description: "Test Delegate ANR Stopped")
    
    var lastANRDetectedType: SentryANRType?
    
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
    
    func anrStopped() {
        anrStoppedExpectation.fulfill()
    }
    
    func anrDetected(_ type: SentryANRType) {
        anrDetectedExpectation.fulfill()
        lastANRDetectedType = type
    }
}

#endif
