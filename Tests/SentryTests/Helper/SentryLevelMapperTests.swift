@testable import Sentry
import XCTest

class SentryLevelMapperTests: XCTestCase {
    func testSentryLevelForString_nilParameter_shouldReturnDefault() {
        XCTAssertEqual(sentryLevelForString(nil), .error)
    }

    func testSentryLevelForString_emptyString_shouldReturnDefault() {
        XCTAssertEqual(sentryLevelForString(""), .error)
    }

    func testSentryLevelForString_invalidString_shouldReturnDefault() {
        XCTAssertEqual(sentryLevelForString("invalid"), .error)
    }

    func testSentryLevelForString_validString_shouldReturnCorrectLevel() {
        XCTAssertEqual(sentryLevelForString("none"), .none)
        XCTAssertEqual(sentryLevelForString("debug"), .debug)
        XCTAssertEqual(sentryLevelForString("info"), .info)
        XCTAssertEqual(sentryLevelForString("warning"), .warning)
        XCTAssertEqual(sentryLevelForString("error"), .error)
        XCTAssertEqual(sentryLevelForString("fatal"), .fatal)
    }
}
