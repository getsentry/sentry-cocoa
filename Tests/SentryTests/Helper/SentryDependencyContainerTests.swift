import Nimble
import XCTest

final class SentryDependencyContainerTests: XCTestCase {
    
    func testReset_CallsFramesTrackerStop() throws {
        let framesTracker = SentryDependencyContainer.sharedInstance().framesTracker
        framesTracker.start()
        SentryDependencyContainer.reset()
        
        expect(framesTracker.isRunning) == false
    }
}
