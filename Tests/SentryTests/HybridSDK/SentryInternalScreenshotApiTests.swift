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
