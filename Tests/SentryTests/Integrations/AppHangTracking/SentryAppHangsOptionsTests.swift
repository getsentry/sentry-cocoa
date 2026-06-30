@testable import Sentry
import XCTest

final class SentryAppHangsOptionsTests: XCTestCase {

    func testEnableV3_default_shouldBeDisabled() {
        let options = AppHangsOptions()
        XCTAssertFalse(options.enableV3)
    }

    func testEnableV3_enabled_shouldBeEnabled() {
        var options = AppHangsOptions()
        options.enableV3 = true
        XCTAssertTrue(options.enableV3)
    }

    func testAppHangDuration_default_shouldBeSetToValue() {
        let options = AppHangsOptions()
        XCTAssertEqual(options.threshold, 2)
    }

    func testAppHangDuration_setTo10Seconds_shouldBeSetTo10Seconds() {
        var options = AppHangsOptions()
        options.threshold = 10.0
        XCTAssertEqual(options.threshold, 10.0)
    }
}
