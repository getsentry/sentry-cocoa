#if SWIFT_PACKAGE && !SDK_V10
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import XCTest

class SentryFileIoTrackingUnitTests: XCTestCase {

    func test_FileIOTracking_Disabled() {
        let options = Options()
        options.enableFileIOTracing = false
        let sut = SentryFileIOTrackingIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance())
        
        XCTAssertNil(sut)
    }
}
