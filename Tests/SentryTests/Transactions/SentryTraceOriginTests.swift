@testable import Sentry
import XCTest

class SentryTraceOriginTestsTests: XCTestCase {
    func testAutoAppStart_shouldBeExpectedValue() {
        XCTAssertEqual(SentryTraceOriginAutoAppStart, "auto.app.start")
    }

    func testAutoAppStartProfile_shouldBeExpectedValue() {
        XCTAssertEqual(SentryTraceOriginAutoAppStartProfile, "auto.app.start.profile")
    }

    func testAutoDBCoreData_shouldBeExpectedValue() {
        XCTAssertEqual(SentryTraceOriginAutoDBCoreData, "auto.db.core_data")
    }

    func testAutoHttpNSURLSession_shouldBeExpectedValue() {
        XCTAssertEqual(SentryTraceOriginAutoHttpNSURLSession, "auto.http.ns_url_session")
    }

    func testAutoNSData_shouldBeExpectedValue() {
        XCTAssertEqual(SentryTraceOriginAutoNSData, "auto.file.ns_data")
    }

    func testAutoUiEventTracker_shouldBeExpectedValue() {
        XCTAssertEqual(SentryTraceOriginAutoUiEventTracker, "auto.ui.event_tracker")
    }

    func testAutoUIViewController_shouldBeExpectedValue() {
        XCTAssertEqual(SentryTraceOriginAutoUIViewController, "auto.ui.view_controller")
    }

    func testAutoUITimeToDisplay_shouldBeExpectedValue() {
        XCTAssertEqual(SentryTraceOriginAutoUITimeToDisplay, "auto.ui.time_to_display")
    }

    func testManual_shouldBeExpectedValue() {
        XCTAssertEqual(SentryTraceOriginManual, "manual")
    }

    func testManualFileData_shouldBeExpectedValue() {
        XCTAssertEqual(SentryTraceOriginManualFileData, "manual.file.data")
    }

    func testManualUITimeToDisplay_shouldBeExpectedValue() {
        XCTAssertEqual(SentryTraceOriginManualUITimeToDisplay, "manual.ui.time_to_display")
    }
}
