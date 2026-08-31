@_spi(Private) @testable import Sentry
import XCTest

class SentryLevelMapperTests: XCTestCase {
    func testLevelForName_whenNilParameter_shouldReturnDefault() {
        XCTAssertEqual(SentryLevelHelper.levelForName(nil), .error)
    }

    func testLevelForName_whenEmptyString_shouldReturnDefault() {
        XCTAssertEqual(SentryLevelHelper.levelForName(""), .error)
    }

    func testLevelForName_whenInvalidString_shouldReturnDefault() {
        XCTAssertEqual(SentryLevelHelper.levelForName("invalid"), .error)
    }

    func testLevelForName_whenValidString_shouldReturnCorrectLevel() {
        XCTAssertEqual(SentryLevelHelper.levelForName("none"), .none)
        XCTAssertEqual(SentryLevelHelper.levelForName("debug"), .debug)
        XCTAssertEqual(SentryLevelHelper.levelForName("info"), .info)
        XCTAssertEqual(SentryLevelHelper.levelForName("warning"), .warning)
        XCTAssertEqual(SentryLevelHelper.levelForName("error"), .error)
        XCTAssertEqual(SentryLevelHelper.levelForName("fatal"), .fatal)
    }
}
