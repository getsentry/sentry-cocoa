import XCTest

class SentryAutoSessionTrackingIntegrationTests: XCTestCase {

    func test_AutoSessionTrackingEnabled_TrackerInitialized() {
        let sut = SentryAutoSessionTrackingIntegration()
        sut.install(with: Options())
        
        XCTAssertNotNil(Dynamic(sut).tracker.asAnyObject)
    }
    
    func test_AutoSessionTrackingDisabled_RemovesEnabledIntegration() {
        let options = Options()
        options.enableAutoSessionTracking = false
        
        let sut = SentryAutoSessionTrackingIntegration()
        sut.install(with: options)
        
        let expexted = Options.defaultIntegrations().filter { !$0.contains("AutoSession") }
        assertArrayEquals(expected: expexted, actual: Array(options.enabledIntegrations))
    }
}
