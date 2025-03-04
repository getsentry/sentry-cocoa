@testable import Sentry
import XCTest

class SentrySpanOperationTests: XCTestCase {
    func testAppLifecycle_shouldBeExpectedValue() {
        XCTAssertEqual(SentrySpanOperationAppLifecycle, "app.lifecycle")
    }

    func testCoredataFetchOperation_shouldBeExpectedValue() {
        XCTAssertEqual(SentrySpanOperationCoredataFetchOperation, "db.sql.query")
    }

    func testCoredataSaveOperation_shouldBeExpectedValue() {
        XCTAssertEqual(SentrySpanOperationCoredataSaveOperation, "db.sql.transaction")
    }

    func testFileRead_shouldBeExpectedValue() {
        XCTAssertEqual(SentrySpanOperationFileRead, "file.read")
    }

    func testFileWrite_shouldBeExpectedValue() {
        XCTAssertEqual(SentrySpanOperationFileWrite, "file.write")
    }

    func testFileCopy_shouldBeExpectedValue() {
        XCTAssertEqual(SentrySpanOperationFileCopy, "file.copy")
    }

    func testFileRename_shouldBeExpectedValue() {
        XCTAssertEqual(SentrySpanOperationFileRename, "file.rename")
    }

    func testFileDelete_shouldBeExpectedValue() {
        XCTAssertEqual(SentrySpanOperationFileDelete, "file.delete")
    }

    func testNetworkRequestOperation_shouldBeExpectedValue() {
        XCTAssertEqual(SentrySpanOperationNetworkRequestOperation, "http.client")
    }

    func testUILoad_shouldBeExpectedValue() {
        XCTAssertEqual(SentrySpanOperationUiLoad, "ui.load")
    }

    func testUILoadInitialDisplay_shouldBeExpectedValue() {
        XCTAssertEqual(SentrySpanOperationUiLoadInitialDisplay, "ui.load.initial_display")
    }

    func testUILoadFullDisplay_shouldBeExpectedValue() {
        XCTAssertEqual(SentrySpanOperationUiLoadFullDisplay, "ui.load.full_display")
    }

    func testUIAction_shouldBeExpectedValue() {
        XCTAssertEqual(SentrySpanOperationUiAction, "ui.action")
    }

    func testUIActionClick_shouldBeExpectedValue() {
        XCTAssertEqual(SentrySpanOperationUiActionClick, "ui.action.click")
    }
}
