@_spi(Private) @testable import Sentry
import XCTest

class SentryXcodeVersionTests: XCTestCase {
    func testXcode16_4_shouldReturnExpectedVersion() {
        XCTAssertEqual(SentryXcodeVersion.xcode16_4.rawValue, 1_640)
    }

    func testXcode26_shouldReturnExpectedVersion() {
        XCTAssertEqual(SentryXcodeVersion.xcode26.rawValue, 2_600)
    }
}
