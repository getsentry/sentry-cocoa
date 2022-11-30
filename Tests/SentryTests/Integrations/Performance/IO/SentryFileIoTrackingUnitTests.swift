import Sentry
import XCTest

class SentryFileIoTrackingUnitTests: XCTestCase {

    func test_FileIOTracking_Disabled() {
        let options = Options()
        options.enableFileIOTracing = false
        let sut = SentryFileIOTrackingIntegration()
        let result = sut.install(with: options)
        
        XCTAssertFalse(result)
    }
}
