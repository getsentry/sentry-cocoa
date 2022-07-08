import Sentry
import XCTest

class SentryFileIoTrackingUnitTests: XCTestCase {

    func test_FileIOTrackingDisabled_RemovesEnabledIntegration() {
        let options = Options()
        options.enableFileIOTracking = false
        let sut = SentryFileIOTrackingIntegration()
        sut.install(with: options)
        
        let expexted = Options.defaultIntegrations().filter { !$0.contains("FileIO") }
        assertArrayEquals(expected: expexted, actual: Array(options.enabledIntegrations))
    }
}
