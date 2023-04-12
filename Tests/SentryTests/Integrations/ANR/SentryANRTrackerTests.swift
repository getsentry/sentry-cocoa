import SentryTestUtils
import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class SentryANRTrackerTests: XCTestCase, SentryANRTrackerDelegate {
    
    private var sut: SentryANRTracker!
    private var fixture: Fixture!
    private var anrDetectedExpectation: XCTestExpectation!
    private var anrStoppedExpectation: XCTestExpectation!
    private let waitTimeout: TimeInterval = 1.0
    
    private class Fixture {
        let timeoutInterval: TimeInterval = 5
        let currentDate = TestCurrentDateProvider()
        let crashWrapper: TestSentryCrashWrapper
        let dispatchQueue = TestSentryDispatchQueueWrapper()
        let threadWrapper = SentryTestThreadWrapper()
        
        init() {
            crashWrapper = TestSentryCrashWrapper()
        }
    }
    
    override func setUp() {
        super.setUp()
        
        anrDetectedExpectation = expectation(description: "ANR Detection")
        anrStoppedExpectation = expectation(description: "ANR Stopped")
        anrStoppedExpectation.isInverted = true
        
        fixture = Fixture()
        
        sut = SentryANRTracker(
            timeoutInterval: fixture.timeoutInterval,
            currentDateProvider: fixture.currentDate,
            crashWrapper: fixture.crashWrapper,
            dispatchQueueWrapper: fixture.dispatchQueue,
            threadWrapper: fixture.threadWrapper)
    }
    
    override func tearDown() {
        super.tearDown()
        sut.clear()
        
        wait(for: [fixture.threadWrapper.threadFinishedExpectation], timeout: 5)
        XCTAssertEqual(0, fixture.threadWrapper.threads.count)
    }
    
    func start() {
        sut.addListener(self)
    }
    
    func testContinuousANR_OneReported() {
        fixture.dispatchQueue.blockBeforeMainBlock = {
            self.advanceTime(bySeconds: self.fixture.timeoutInterval)
            return false
        }
        start()
        
        wait(for: [anrDetectedExpectation, anrStoppedExpectation], timeout: waitTimeout)
    }
    
    func testMultipleListeners() {
        fixture.dispatchQueue.blockBeforeMainBlock = {
            self.advanceTime(bySeconds: self.fixture.timeoutInterval)
            return false
        }
        
        let secondListener = SentryANRTrackerTestDelegate()
        sut.addListener(secondListener)
        
        start()
        
        wait(for: [anrDetectedExpectation, anrStoppedExpectation, secondListener.anrStoppedExpectation, secondListener.anrDetectedExpectation], timeout: waitTimeout)
    }
    
    func testANRButAppInBackground_NoANR() {
        anrDetectedExpectation.isInverted = true
        fixture.crashWrapper.internalIsApplicationInForeground = false
        
        fixture.dispatchQueue.blockBeforeMainBlock = {
            self.advanceTime(bySeconds: self.fixture.timeoutInterval)
            return false
        }
        start()
        
        wait(for: [anrDetectedExpectation, anrStoppedExpectation], timeout: waitTimeout)
    }
    
    func testMultipleANRs_MultipleReported() {
        anrDetectedExpectation.expectedFulfillmentCount = 3
        let expectedANRStoppedInvocations = 2
        anrStoppedExpectation.isInverted = false
        anrStoppedExpectation.expectedFulfillmentCount = expectedANRStoppedInvocations
        
        fixture.dispatchQueue.blockBeforeMainBlock = {
            self.advanceTime(bySeconds: self.fixture.timeoutInterval)
            let invocations = self.fixture.dispatchQueue.blockOnMainInvocations.count
            if [0, 10, 15, 25].contains(invocations) {
                return true
            }
            
            return false
        }
        start()
        
        wait(for: [anrDetectedExpectation, anrStoppedExpectation], timeout: waitTimeout)
        XCTAssertEqual(expectedANRStoppedInvocations, fixture.dispatchQueue.dispatchAsyncInvocations.count)
    }
    
    func testAppSuspended_NoANR() {
        anrDetectedExpectation.isInverted = true
        fixture.dispatchQueue.blockBeforeMainBlock = {
            let delta = self.fixture.timeoutInterval * 2
            self.advanceTime(bySeconds: delta)
            return false
        }
        start()
        
        wait(for: [anrDetectedExpectation, anrStoppedExpectation], timeout: waitTimeout)
    }
    
    func testRemoveListener_StopsReportingANRs() {
        anrDetectedExpectation.isInverted = true
        
        let mainBlockExpectation = expectation(description: "Main Block")
       
        fixture.dispatchQueue.blockBeforeMainBlock = {
            self.sut.removeListener(self)
            mainBlockExpectation.fulfill()
            return true
        }
        
        start()
        
        wait(for: [anrDetectedExpectation, anrStoppedExpectation, mainBlockExpectation], timeout: waitTimeout)
    }
    
    func testClear_StopsReportingANRs() {
        let secondListener = SentryANRTrackerTestDelegate()
        secondListener.anrDetectedExpectation.isInverted = true
        anrDetectedExpectation.isInverted = true
        
        let mainBlockExpectation = expectation(description: "Main Block")
        
        //Having a second Listener may cause the tracker to execute more than once before the end of the test
        mainBlockExpectation.assertForOverFulfill = false
                
        fixture.dispatchQueue.blockBeforeMainBlock = {
            self.sut.clear()
            mainBlockExpectation.fulfill()
            return true
        }
        
        sut.addListener(secondListener)
        start()
        wait(for: [anrDetectedExpectation, anrStoppedExpectation, mainBlockExpectation, secondListener.anrStoppedExpectation, secondListener.anrDetectedExpectation], timeout: waitTimeout)

    }
    
    func testNotRemovingDeallocatedListener_DoesNotRetainListener_AndStopsTracking() {
        anrDetectedExpectation.isInverted = true
        anrStoppedExpectation.isInverted = true
        
        // So ARC deallocates SentryANRTrackerTestDelegate
        let addListenersCount = 10
        func addListeners() {
            for _ in 0..<addListenersCount {
                self.sut.addListener(SentryANRTrackerTestDelegate())
            }
        }
        addListeners()
        
        sut.addListener(self)
        sut.removeListener(self)
        
        let listeners = Dynamic(sut).listeners.asObject as? NSHashTable<NSObject>
        
        XCTAssertGreaterThan(addListenersCount, listeners?.count ?? addListenersCount)
        
        wait(for: [anrDetectedExpectation, anrStoppedExpectation], timeout: 0.0)
    }
    
    func testClearDirectlyAfterStart() {
        anrDetectedExpectation.isInverted = true
        
        let invocations = 10
        for _ in 0..<invocations {
            sut.addListener(self)
            sut.clear()
        }
        
        wait(for: [anrDetectedExpectation, anrStoppedExpectation], timeout: 1)
        
        XCTAssertEqual(0, fixture.threadWrapper.threads.count)
        XCTAssertEqual(1, fixture.threadWrapper.threadStartedInvocations.count)
        XCTAssertEqual(1, fixture.threadWrapper.threadFinishedInvocations.count)
    }
    
    func anrDetected() {
        anrDetectedExpectation.fulfill()
    }
    
    func anrStopped() {
        anrStoppedExpectation.fulfill()
    }
    
    private func advanceTime(bySeconds: TimeInterval) {
        fixture.currentDate.setDate(date: fixture.currentDate.date().addingTimeInterval(bySeconds))
    }
}

class SentryANRTrackerTestDelegate: NSObject, SentryANRTrackerDelegate {
    
    let anrDetectedExpectation = XCTestExpectation(description: "Test Delegate ANR Detection")
    let anrStoppedExpectation  = XCTestExpectation(description: "Test Delegate ANR Stopped")
    
    override init() {
        anrStoppedExpectation.isInverted = true
    }
    
    func anrStopped() {
        anrStoppedExpectation.fulfill()
    }
    
    func anrDetected() {
        anrDetectedExpectation.fulfill()
    }
}

#endif
