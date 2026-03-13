@testable import Sentry
import XCTest

class SentryLevelMapperTests: XCTestCase {
    func testSentryLevelForString_whenNilParameter_shouldReturnDefault() {
        XCTAssertEqual(sentryLevelForString(nil), .error)
    }

    func testSentryLevelForString_whenEmptyString_shouldReturnDefault() {
        XCTAssertEqual(sentryLevelForString(""), .error)
    }

    func testSentryLevelForString_whenInvalidString_shouldReturnDefault() {
        XCTAssertEqual(sentryLevelForString("invalid"), .error)
    }

    func testSentryLevelForString_whenValidString_shouldReturnCorrectLevel() {
        XCTAssertEqual(sentryLevelForString("none"), .none)
        XCTAssertEqual(sentryLevelForString("debug"), .debug)
        XCTAssertEqual(sentryLevelForString("info"), .info)
        XCTAssertEqual(sentryLevelForString("warning"), .warning)
        XCTAssertEqual(sentryLevelForString("error"), .error)
        XCTAssertEqual(sentryLevelForString("fatal"), .fatal)
    }
}
