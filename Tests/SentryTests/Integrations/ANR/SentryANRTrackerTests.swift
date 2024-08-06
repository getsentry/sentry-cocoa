@testable import Sentry
import SentryTestUtils
import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class SentryANRTrackerTests: XCTestCase {
    
    private let waitTimeout: TimeInterval = 1.0
    private let timeoutInterval: TimeInterval = 2
        
    private func getSut() throws -> (SentryANRTracker, TestCurrentDateProvider, TestDisplayLinkWrapper, TestSentryCrashWrapper, SentryTestThreadWrapper) {
        
        let currentDate = TestCurrentDateProvider()
        let crashWrapper = TestSentryCrashWrapper.sharedInstance()
        let dispatchQueue = TestSentryDispatchQueueWrapper()
        let threadWrapper = SentryTestThreadWrapper()
        let displayLinkWrapper = TestDisplayLinkWrapper()
        
        SentryDependencyContainer.sharedInstance().dateProvider = currentDate
        
        displayLinkWrapper.dateProvider = currentDate
        let framesTracker = SentryFramesTracker(displayLinkWrapper: displayLinkWrapper, dateProvider: currentDate, dispatchQueueWrapper: dispatchQueue, notificationCenter: TestNSNotificationCenterWrapper(), keepDelayedFramesDuration: 30)
        
        framesTracker.start()
        
        // Add a couple of normal frames, so that querying for frame delay
        // has enough data to not return -1.
        for _ in 0..<1_000 {
            displayLinkWrapper.normalFrame()
        }
        
        return (SentryANRTracker(
            timeoutInterval: timeoutInterval,
            crashWrapper: crashWrapper,
            dispatchQueueWrapper: dispatchQueue,
            threadWrapper: threadWrapper,
            framesTracker: framesTracker), currentDate, displayLinkWrapper, crashWrapper, threadWrapper)
    }
    
    override func setUp() {
        super.setUp()
        
        // To avoid spamming the test logs
        SentryLog.configure(true, diagnosticLevel: .error)
    }
    
    override func tearDown() {
        super.tearDown()
        
        SentryLog.setTestDefaultLogLevel()
    }
    
    func testNonFullyBlockingContinuousANRs_OneReported() throws {
        let (sut, _, displayLinkWrapper, _, _) = try getSut()
        defer { sut.clear() }
        
        let listener = SentryANRTrackerTestDelegate()
        
        sut.addListener(listener)
        
        for _ in 0..<10 {
            _ = displayLinkWrapper.fastestFrozenFrame()
        }
        
        wait(for: [listener.anrDetectedExpectation], timeout: waitTimeout)
        XCTAssertEqual(SentryANRType.nonFullyBlocking, listener.lastANRDetectedType)
        
        for _ in 0..<100 {
            displayLinkWrapper.normalFrame()
        }
        
        wait(for: [listener.anrStoppedExpectation], timeout: waitTimeout)
    }
    
    func testFullyBlockingContinuousANRs_OneReported() throws {
        let (sut, _, displayLinkWrapper, _, _) = try getSut()
        defer { sut.clear() }
        
        let listener = SentryANRTrackerTestDelegate()
        
        sut.addListener(listener)
        
        displayLinkWrapper.frozenFrame(duration: timeoutInterval * 2.0)
        
        wait(for: [listener.anrDetectedExpectation], timeout: waitTimeout)
        XCTAssertEqual(SentryANRType.fullyBlocking, listener.lastANRDetectedType)
        
        for _ in 0..<100 {
            displayLinkWrapper.normalFrame()
        }
        
        wait(for: [listener.anrStoppedExpectation], timeout: waitTimeout)
    }
    
    func testMultipleListeners() throws {
        let (sut, _, displayLinkWrapper, _, _) = try getSut()
        defer { sut.clear() }
        
        let firstListener = SentryANRTrackerTestDelegate()
        
        sut.addListener(firstListener)
        
        let secondListener = SentryANRTrackerTestDelegate()
        sut.addListener(secondListener)
        
        displayLinkWrapper.frozenFrame(duration: timeoutInterval * 2.0)
        
        wait(for: [firstListener.anrDetectedExpectation, secondListener.anrDetectedExpectation], timeout: waitTimeout)
        
        XCTAssertEqual(SentryANRType.fullyBlocking, firstListener.lastANRDetectedType)
        XCTAssertEqual(SentryANRType.fullyBlocking, secondListener.lastANRDetectedType)
        
        for _ in 0..<100 {
            displayLinkWrapper.normalFrame()
        }
        
        wait(for: [firstListener.anrStoppedExpectation, secondListener.anrStoppedExpectation], timeout: waitTimeout)
    }
    
    func testFullyBlockingANR_ButAppInBackground_NoANRReported() throws {
        let (sut, _, displayLinkWrapper, crashWrapper, _) = try getSut()
        defer { sut.clear() }
        
        crashWrapper.internalIsApplicationInForeground = false
        
        let listener = SentryANRTrackerTestDelegate(shouldANRBeDetected: false, shouldStoppedBeCalled: false)
        
        sut.addListener(listener)
        
        displayLinkWrapper.frozenFrame(duration: timeoutInterval * 2.0)
        
        wait(for: [listener.anrDetectedExpectation, listener.anrStoppedExpectation], timeout: waitTimeout)
    }
    
    func testNonFullyBlockingANR_ButAppInBackground_NoANRReported() throws {
        let (sut, _, displayLinkWrapper, crashWrapper, _) = try getSut()
        defer { sut.clear() }
        
        crashWrapper.internalIsApplicationInForeground = false
        
        let listener = SentryANRTrackerTestDelegate(shouldANRBeDetected: false, shouldStoppedBeCalled: false)
        
        sut.addListener(listener)
        
        for _ in 0..<10 {
            _ = displayLinkWrapper.fastestFrozenFrame()
        }
        
        wait(for: [listener.anrDetectedExpectation, listener.anrStoppedExpectation], timeout: waitTimeout)
    }
    
    func testMultipleANRs_MultipleReported() throws {
        let (sut, _, displayLinkWrapper, _, _) = try getSut()
        defer { sut.clear() }
        
        let firstListener = SentryANRTrackerTestDelegate()
        sut.addListener(firstListener)
    
        for _ in 0..<10 {
            _ = displayLinkWrapper.fastestFrozenFrame()
        }
        
        wait(for: [firstListener.anrDetectedExpectation], timeout: waitTimeout)
        
        for _ in 0..<100 {
            displayLinkWrapper.normalFrame()
        }
        
        wait(for: [firstListener.anrStoppedExpectation], timeout: waitTimeout)
        
        let secondListener = SentryANRTrackerTestDelegate()
        
        sut.addListener(secondListener)
        
        for _ in 0..<10 {
            _ = displayLinkWrapper.fastestFrozenFrame()
        }
        
        wait(for: [secondListener.anrDetectedExpectation], timeout: waitTimeout)
        
        for _ in 0..<100 {
            displayLinkWrapper.normalFrame()
        }
        
        wait(for: [secondListener.anrStoppedExpectation], timeout: waitTimeout)
    }
    
    func testAppSuspended_NoANR() throws {
        let (sut, currentDate, displayLinkWrapper, _, threadWrapper) = try getSut()
        defer { sut.clear() }
        
        let listener = SentryANRTrackerTestDelegate(shouldANRBeDetected: false, shouldStoppedBeCalled: false)
        
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
        
        let listener = SentryANRTrackerTestDelegate(shouldANRBeDetected: false, shouldStoppedBeCalled: false)
        
        let mainBlockExpectation = expectation(description: "Main Block")
        
        threadWrapper.blockWhenSleeping = {
            sut.removeListener(listener)
            mainBlockExpectation.fulfill()
        }
        
        displayLinkWrapper.frozenFrame(duration: 10.0)
        
        sut.addListener(listener)
        
        wait(for: [listener.anrDetectedExpectation, listener.anrStoppedExpectation, mainBlockExpectation], timeout: waitTimeout)
    }
    
    func testClear_StopsReportingANRs() throws {
        let (sut, _, _, _, threadWrapper) = try getSut()
        defer { sut.clear() }
        
        let firstListener = SentryANRTrackerTestDelegate(shouldANRBeDetected: false, shouldStoppedBeCalled: false)
        let secondListener = SentryANRTrackerTestDelegate(shouldANRBeDetected: false, shouldStoppedBeCalled: false)
        
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
        
        let listener = SentryANRTrackerTestDelegate(shouldANRBeDetected: false, shouldStoppedBeCalled: false)
        
        // So ARC deallocates SentryANRTrackerTestDelegate
        let addListenersCount = 10
        func addListeners() {
            for _ in 0..<addListenersCount {
                sut.addListener(SentryANRTrackerTestDelegate())
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
        
        sut.addListener(SentryANRTrackerTestDelegate())
        
        sut.clear()
        
        wait(for: [threadWrapper.threadFinishedExpectation], timeout: 5)
        XCTAssertEqual(0, threadWrapper.threads.count)
    }
    
    func testClearDirectlyAfterStart() throws {
        let (sut, _, displayLinkWrapper, _, threadWrapper) = try getSut()
        defer { sut.clear() }
        
        let listener = SentryANRTrackerTestDelegate(shouldANRBeDetected: false, shouldStoppedBeCalled: false)
        
        displayLinkWrapper.frozenFrame(duration: timeoutInterval * 2)
        
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

class SentryANRTrackerTestDelegate: NSObject, SentryANRTrackerDelegate {
    
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
