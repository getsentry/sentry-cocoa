@testable import Sentry
import XCTest

class SentrySpanOperationTests: XCTestCase {
    func testAppLifecycle_shouldBeExpectedValue() {
        XCTAssertEqual(SentrySpanOperation.appLifecycle, "app.lifecycle")
    }

    func testCoredataFetchOperation_shouldBeExpectedValue() {
        XCTAssertEqual(SentrySpanOperation.coredataFetchOperation, "db.sql.query")
    }

    func testCoredataSaveOperation_shouldBeExpectedValue() {
        XCTAssertEqual(SentrySpanOperation.coredataSaveOperation, "db.sql.transaction")
    }

    func testFileRead_shouldBeExpectedValue() {
        XCTAssertEqual(SentrySpanOperation.fileRead, "file.read")
    }

    func testFileWrite_shouldBeExpectedValue() {
        XCTAssertEqual(SentrySpanOperation.fileWrite, "file.write")
    }

    func testNetworkRequestOperation_shouldBeExpectedValue() {
        XCTAssertEqual(SentrySpanOperation.networkRequestOperation, "http.client")
    }

    func testUILoad_shouldBeExpectedValue() {
        XCTAssertEqual(SentrySpanOperation.uiLoad, "ui.load")
    }

    func testUILoadInitialDisplay_shouldBeExpectedValue() {
        XCTAssertEqual(SentrySpanOperation.uiLoadInitialDisplay, "ui.load.initial_display")
    }

    func testUILoadFullDisplay_shouldBeExpectedValue() {
        XCTAssertEqual(SentrySpanOperation.uiLoadFullDisplay, "ui.load.full_display")
    }

    func testUIAction_shouldBeExpectedValue() {
        XCTAssertEqual(SentrySpanOperation.uiAction, "ui.action")
    }

    func testUIActionClick_shouldBeExpectedValue() {
        XCTAssertEqual(SentrySpanOperation.uiActionClick, "ui.action.click")
    }
}
