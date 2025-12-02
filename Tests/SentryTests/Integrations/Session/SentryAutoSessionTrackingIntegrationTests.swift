@_spi(Private) @testable import Sentry
import SentryTestUtils
import XCTest

class SentryAutoSessionTrackingIntegrationTests: XCTestCase {

    func test_AutoSessionTracking_Disabled() {
        let options = Options()
        options.enableAutoSessionTracking = false
        
        let sut = SentryAutoSessionTrackingIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance())
        
        XCTAssertNil(sut)
    }
    
    func test_AutoSessionTracking_Enabled() {
        let options = Options()
        options.enableAutoSessionTracking = true
        
        let sut = SentryAutoSessionTrackingIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance())
        defer {
            sut?.uninstall()
        }
        
        XCTAssertNotNil(sut)
    }
}
