@_spi(Private) @testable import Sentry
import XCTest

final class SentryExperimentalOptionsTests: XCTestCase {

    // MARK: - enableUIViewControllerInitSwizzling

    func testEnableUIViewControllerInitSwizzling_whenDefault_shouldBeFalse() {
        // -- Act --
        let options = SentryExperimentalOptions()

        // -- Assert --
        XCTAssertFalse(options.enableUIViewControllerInitSwizzling)
    }

    func testEnableUIViewControllerInitSwizzling_whenSetToTrue_shouldReturnTrue() {
        // -- Arrange --
        let options = SentryExperimentalOptions()

        // -- Act --
        options.enableUIViewControllerInitSwizzling = true

        // -- Assert --
        XCTAssertTrue(options.enableUIViewControllerInitSwizzling)
    }

    func testEnableUIViewControllerInitSwizzling_whenSetToFalse_shouldReturnFalse() {
        // -- Arrange --
        let options = SentryExperimentalOptions()
        options.enableUIViewControllerInitSwizzling = true

        // -- Act --
        options.enableUIViewControllerInitSwizzling = false

        // -- Assert --
        XCTAssertFalse(options.enableUIViewControllerInitSwizzling)
    }

    // MARK: - Options.experimental

    func testOptionsExperimental_enableUIViewControllerInitSwizzling_whenDefault_shouldBeFalse() {
        // -- Act --
        let options = Options()

        // -- Assert --
        XCTAssertFalse(options.experimental.enableUIViewControllerInitSwizzling)
    }

    func testOptionsExperimental_enableUIViewControllerInitSwizzling_whenSet_shouldRetainValue() {
        // -- Arrange --
        let options = Options()

        // -- Act --
        options.experimental.enableUIViewControllerInitSwizzling = true

        // -- Assert --
        XCTAssertTrue(options.experimental.enableUIViewControllerInitSwizzling)
    }
}
