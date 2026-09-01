@_spi(Private) @testable import Sentry
import XCTest

#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK

class SentryInternalViewHierarchyApiTests: XCTestCase {

    // MARK: - capture

    func testCapture_whenNoViewHierarchyProviderAvailable_shouldReturnNil() {
        // -- Arrange --
        let sut = SentryInternalViewHierarchyApi(dependencies: MockViewHierarchyProviderProvider())

        // -- Act --
        let result = sut.capture()

        // -- Assert --
        XCTAssertNil(result)
    }
}

private class MockViewHierarchyProviderProvider: ViewHierarchyProviderProvider {
    var viewHierarchyProvider: SentryViewHierarchyProvider?
}

#endif
