import XCTest

class SentryAutoSessionTrackingIntegrationTests: XCTestCase {

    func test_AutoSessionTrackingEnabled_TrackerInitialized() {
        let sut = SentryAutoSessionTrackingIntegration()
        sut.install(with: Options())
        
        XCTAssertNotNil(Dynamic(sut).tracker.asAnyObject)
    }
    
    func test_AutoSessionTracking_Disabled() {
        let options = Options()
        options.enableAutoSessionTracking = false
        
        let sut = SentryAutoSessionTrackingIntegration()
        let result = sut.install(with: options)
        
        XCTAssertFalse(result)
    }
}
