@testable import Sentry
import XCTest

class SentryTraceOriginTestsTests: XCTestCase {
    func testAutoAppStart_shouldBeExpectedValue() {
        XCTAssertEqual(SentryTraceOrigin.autoAppStart, "auto.app.start")
    }

    func testAutoAppStartProfile_shouldBeExpectedValue() {
        XCTAssertEqual(SentryTraceOrigin.autoAppStartProfile, "auto.app.start.profile")
    }

    func testAutoDBCoreData_shouldBeExpectedValue() {
        XCTAssertEqual(SentryTraceOrigin.autoDBCoreData, "auto.db.core_data")
    }

    func testAutoHttpNSURLSession_shouldBeExpectedValue() {
        XCTAssertEqual(SentryTraceOrigin.autoHttpNSURLSession, "auto.http.ns_url_session")
    }

    func testAutoNSData_shouldBeExpectedValue() {
        XCTAssertEqual(SentryTraceOrigin.autoNSData, "auto.file.ns_data")
    }

    func testAutoUiEventTracker_shouldBeExpectedValue() {
        XCTAssertEqual(SentryTraceOrigin.autoUiEventTracker, "auto.ui.event_tracker")
    }

    func testAutoUIViewController_shouldBeExpectedValue() {
        XCTAssertEqual(SentryTraceOrigin.autoUIViewController, "auto.ui.view_controller")
    }

    func testAutoUITimeToDisplay_shouldBeExpectedValue() {
        XCTAssertEqual(SentryTraceOrigin.autoUITimeToDisplay, "auto.ui.time_to_display")
    }

    func testManual_shouldBeExpectedValue() {
        XCTAssertEqual(SentryTraceOrigin.manual, "manual")
    }

    func testManualUITimeToDisplay_shouldBeExpectedValue() {
        XCTAssertEqual(SentryTraceOrigin.manualUITimeToDisplay, "manual.ui.time_to_display")
    }
}
