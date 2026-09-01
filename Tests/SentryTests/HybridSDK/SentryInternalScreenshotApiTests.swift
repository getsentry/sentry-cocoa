@_spi(Private) @testable import Sentry
import XCTest

#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK

class SentryInternalScreenshotApiTests: XCTestCase {

    // MARK: - capture

    func testCapture_whenNoScreenshotSourceAvailable_shouldReturnNil() {
        // -- Arrange --
        let container = SentryDependencyContainer.sharedInstance()
        let sut = SentryInternalScreenshotApi(dependencies: container)

        // -- Act --
        let result = sut.capture()

        // -- Assert --
        XCTAssertNil(result)
    }
}

#endif
