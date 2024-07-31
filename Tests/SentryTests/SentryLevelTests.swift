import Foundation
@testable import Sentry
import XCTest

class SentryLevelTests: XCTestCase {
    
    func testNames() {
        XCTAssertEqual(SentryLevel.none, SentryLevel.fromName("none"))
        XCTAssertEqual(SentryLevel.debug, SentryLevel.fromName("debug"))
        XCTAssertEqual(SentryLevel.error, SentryLevel.fromName("error"))
        XCTAssertEqual(SentryLevel.info, SentryLevel.fromName("info"))
        XCTAssertEqual(SentryLevel.fatal, SentryLevel.fromName("fatal"))
        XCTAssertEqual(SentryLevel.warning, SentryLevel.fromName("warning"))
        XCTAssertEqual(SentryLevel.error, SentryLevel.fromName("invalid"))
        
        XCTAssertEqual(SentryLevel.none.description, "none")
        XCTAssertEqual(SentryLevel.debug.description, "debug")
        XCTAssertEqual(SentryLevel.error.description, "error")
        XCTAssertEqual(SentryLevel.info.description, "info")
        XCTAssertEqual(SentryLevel.fatal.description, "fatal")
        XCTAssertEqual(SentryLevel.warning.description, "warning")
    }
}
