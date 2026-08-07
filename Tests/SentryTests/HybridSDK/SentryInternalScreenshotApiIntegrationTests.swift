@testable import Sentry
import SentryTestUtils
import XCTest

#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK

class SentryInternalScreenshotApiIntegrationTests: XCTestCase {

    private static let dsnAsString = TestConstants.dsnForTestCase(type: SentryInternalScreenshotApiIntegrationTests.self)

    override func setUp() {
        super.setUp()
        SentrySDK.start { options in
            options.dsn = SentryInternalScreenshotApiIntegrationTests.dsnAsString
            options.removeAllIntegrations()
        }
    }

    override func tearDown() {
        // swiftlint:disable:next avoid_clear_test_state - just disabled to allow adding the SwiftLint rule. Please double check if you can remove this when touching this.
        clearTestState()
        super.tearDown()
    }

    // MARK: - accessor

    func testScreenshot_shouldBeAccessible() {
        // -- Act --
        let screenshot = SentrySDK.internal.screenshot

        // -- Assert --
        XCTAssertNotNil(screenshot)
    }

    // MARK: - capture

    func testCapture_whenNoWindows_shouldReturnEmptyArray() {
        // -- Act --
        let result = SentrySDK.internal.screenshot.capture()

        // -- Assert --
        XCTAssertEqual(result, [])
    }
}

#endif
