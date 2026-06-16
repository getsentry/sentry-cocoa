@_spi(Private) @testable import Sentry
import XCTest

#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK

class SentryInternalViewHierarchyApiTests: XCTestCase {

    // MARK: - capture

    func testCapture_whenNoViewHierarchyProviderAvailable_shouldReturnNil() {
        // -- Arrange --
        let container = SentryDependencyContainer.sharedInstance()
        let sut = SentryInternalViewHierarchyApi(dependencies: container)

        // -- Act --
        let result = sut.capture()

        // -- Assert --
        XCTAssertNil(result)
    }
}

#endif
