import XCTest

final class SentryDependencyContainerTests: XCTestCase {

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    func testReset_CallsFramesTrackerStop() throws {
        let framesTracker = SentryDependencyContainer.sharedInstance().framesTracker
        framesTracker.start()
        SentryDependencyContainer.reset()
        
        XCTAssertFalse(framesTracker.isRunning)
    }
    
    func testGetANRTrackerV2() {
        let instance = SentryDependencyContainer.sharedInstance().getANRTracker(2.0, isV2Enabled: true)
        XCTAssertTrue(instance is SentryANRTrackerV2)
        
        SentryDependencyContainer.reset()
        
    }
    
    func testGetANRTrackerV1() {
        let instance = SentryDependencyContainer.sharedInstance().getANRTracker(2.0, isV2Enabled: false)
        XCTAssertTrue(instance is SentryANRTrackerV1)
        
        SentryDependencyContainer.reset()
    }
    
    func testGetANRTrackerV2AndThenV1_FirstCalledVersionStaysTheSame() {
        let instance1 = SentryDependencyContainer.sharedInstance().getANRTracker(2.0, isV2Enabled: true)
        XCTAssertTrue(instance1 is SentryANRTrackerV2)
        
        let instance2 = SentryDependencyContainer.sharedInstance().getANRTracker(2.0, isV2Enabled: false)
        XCTAssertTrue(instance2 is SentryANRTrackerV2)
        
        SentryDependencyContainer.reset()
    }
    
    func testGetANRTrackerV1AndThenV2_FirstCalledVersionStaysTheSame() {
        let instance1 = SentryDependencyContainer.sharedInstance().getANRTracker(2.0, isV2Enabled: false)
        XCTAssertTrue(instance1 is SentryANRTrackerV1)
        
        let instance2 = SentryDependencyContainer.sharedInstance().getANRTracker(2.0, isV2Enabled: true)
        XCTAssertTrue(instance2 is SentryANRTrackerV1)
        
        SentryDependencyContainer.reset()
    }
    
#endif
    
    func testGetANRTracker_ReturnsV1() {
        
        let instance = SentryDependencyContainer.sharedInstance().getANRTracker(2.0)
        XCTAssertTrue(instance is SentryANRTrackerV1)

        SentryDependencyContainer.reset()
    }
}
