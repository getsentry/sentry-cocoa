import XCTest

class SentryUIPerformanceTrackerTests: XCTestCase {
    private class TestViewController : UIViewController {
        
    }
    
    private class Fixture {
        
        let viewController = TestViewController()
        
        func getSut() -> SentryUIPerformanceTracker {
            return SentryUIPerformanceTracker()
        }
    }
    
    
}
