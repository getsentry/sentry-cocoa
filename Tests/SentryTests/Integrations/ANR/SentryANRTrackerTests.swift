import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class SentryANRTrackerTests: XCTestCase, SentryANRTrackerDelegate {
    
    private var sut: SentryANRTracker!
    private var fixture: Fixture!
    private var anrDetectedExpectation: XCTestExpectation!
    private var anrStoppedExpectation: XCTestExpectation!
    private let waitTimeout: TimeInterval = 0.05
    
    private class Fixture {
        let timeoutInterval: TimeInterval = 5
        let currentDate = TestCurrentDateProvider()
        let crashWrapper: TestSentryCrashWrapper
        let dispatchQueue = TestSentryDispatchQueueWrapper()
        let threadWrapper = SentryTestThreadWrapper()
        
        init() {
            crashWrapper = TestSentryCrashWrapper.sharedInstance()
        }
    }
    
    override func setUp() {
        super.setUp()
        
        anrDetectedExpectation = expectation(description: "ANR Detection")
        anrStoppedExpectation = expectation(description: "ANR Stopped")
        anrStoppedExpectation.isInverted = true
        
        fixture = Fixture()
        
        sut = SentryANRTracker(delegate: self,
                               timeoutIntervalMillis: UInt(fixture.timeoutInterval) * 1_000,
                               currentDateProvider: fixture.currentDate,
                               crashWrapper: fixture.crashWrapper,
                               dispatchQueueWrapper: fixture.dispatchQueue,
                               threadWrapper: fixture.threadWrapper)
    }
    
    override func tearDown() {
        super.tearDown()
        sut.stop()
    }
    
    func testContinousANR_OneReported() {
        fixture.dispatchQueue.blockBeforeMainBlock = {
            self.advanceTime(bySeconds: self.fixture.timeoutInterval)
            return false
        }
        sut.start()
        
        wait(for: [anrDetectedExpectation, anrStoppedExpectation], timeout: waitTimeout)
    }
    
    func testANRButAppInBackground_NoANR() {
        anrDetectedExpectation.isInverted = true
        fixture.crashWrapper.internalIsApplicationInForeground = false
        
        fixture.dispatchQueue.blockBeforeMainBlock = {
            self.advanceTime(bySeconds: self.fixture.timeoutInterval)
            return false
        }
        sut.start()
        
        wait(for: [anrDetectedExpectation, anrStoppedExpectation], timeout: waitTimeout)
    }
    
    func testMultipleANRs_MultipleReported() {
        anrDetectedExpectation.expectedFulfillmentCount = 3
        anrStoppedExpectation.isInverted = false
        anrStoppedExpectation.expectedFulfillmentCount = 2
        
        fixture.dispatchQueue.blockBeforeMainBlock = {
            self.advanceTime(bySeconds: self.fixture.timeoutInterval)
            let invocations = self.fixture.dispatchQueue.blockOnMainInvocations.count
            if [0, 2, 3, 5].contains(invocations) {
                return true
            }
            
            return false
        }
        sut.start()
        
        wait(for: [anrDetectedExpectation, anrStoppedExpectation], timeout: waitTimeout)
    }
    
    func testAppSuspended_NoANR() {
        anrDetectedExpectation.isInverted = true
        fixture.dispatchQueue.blockBeforeMainBlock = {
            let delta = self.fixture.timeoutInterval * 2
            self.advanceTime(bySeconds: delta)
            return false
        }
        sut.start()
        
        wait(for: [anrDetectedExpectation, anrStoppedExpectation], timeout: waitTimeout)
    }
    
    func testStop_StopsReportingANRs() {
        anrDetectedExpectation.isInverted = true
        
        let mainBlockExpectation = expectation(description: "Main Block")
        fixture.dispatchQueue.blockBeforeMainBlock = {
            self.sut.stop()
            mainBlockExpectation.fulfill()
            return true
        }
        
        sut.start()
        
        wait(for: [anrDetectedExpectation, anrStoppedExpectation, mainBlockExpectation], timeout: waitTimeout)
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
#endif
