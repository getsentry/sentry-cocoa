#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
import _SentryPrivate
import SentryObjCInternal
import SentryTestsObjCHelpers
#else
@_spi(Private) @testable import Sentry
#endif
import XCTest

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

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
