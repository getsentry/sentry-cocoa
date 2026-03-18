import Foundation
@testable import Sentry
import XCTest

class SentryLevelTests: XCTestCase {

    func testNone_shouldReturnCorrectLevelAndDescription() {
        XCTAssertEqual(SentryLevel.fromName("none"), SentryLevel.none)
        XCTAssertEqual(SentryLevel.none.description, "none")
    }

    func testDebug_shouldReturnCorrectLevelAndDescription() {
        XCTAssertEqual(SentryLevel.fromName("debug"), SentryLevel.debug)
        XCTAssertEqual(SentryLevel.debug.description, "debug")
    }

    func testInfo_shouldReturnCorrectLevelAndDescription() {
        XCTAssertEqual(SentryLevel.fromName("info"), SentryLevel.info)
        XCTAssertEqual(SentryLevel.info.description, "info")
    }

    func testWarning_shouldReturnCorrectLevelAndDescription() {
        XCTAssertEqual(SentryLevel.fromName("warning"), SentryLevel.warning)
        XCTAssertEqual(SentryLevel.warning.description, "warning")
    }

    func testError_shouldReturnCorrectLevelAndDescription() {
        XCTAssertEqual(SentryLevel.fromName("error"), SentryLevel.error)
        XCTAssertEqual(SentryLevel.error.description, "error")
    }

    func testFatal_shouldReturnCorrectLevelAndDescription() {
        XCTAssertEqual(SentryLevel.fromName("fatal"), SentryLevel.fatal)
        XCTAssertEqual(SentryLevel.fatal.description, "fatal")
    }

    func testFromName_whenInvalid_shouldReturnError() {
        XCTAssertEqual(SentryLevel.fromName("invalid"), SentryLevel.error)
    }
}
