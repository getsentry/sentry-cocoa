import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
final class SentryDependencyContainerTests: XCTestCase {
    
    func testReset_CallsFramesTrackerStop() throws {
        let framesTracker = SentryDependencyContainer.sharedInstance().framesTracker
        framesTracker.start()
        SentryDependencyContainer.reset()
        
        XCTAssertFalse(framesTracker.isRunning)
    }
}
#endif
