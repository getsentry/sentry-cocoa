import XCTest

class LaunchUITests: XCTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
    }

    func testTransactionSpan() {
        let app = XCUIApplication()
        app.launch()
        
        let transactionName = app.staticTexts["TRANSACTION_NAME"]
        let transactionId = app.staticTexts["TRANSACTION_ID"]
        if !transactionName.waitForExistence(timeout: 1) {
            XCTFail("Span operation label not found")
        }
        
        let childParentId = app.staticTexts["CHILD_PARENT_SPANID"]
        let childName = app.staticTexts["CHILD_NAME"]
        
        XCTAssertEqual(childName.label, "Child Span")
        XCTAssertEqual(transactionName.label, "Content View Body")
        XCTAssertEqual(childParentId.label, transactionId.label)
        XCTAssertEqual("auto.ui.swift_ui", app.staticTexts["TRACE_ORIGIN"].label)
        XCTAssertEqual("auto.ui.swift_ui", app.staticTexts["CHILD_TRACE_ORIGIN"].label)
    }

    func testNoNewTransactionForSecondCallToBody() {
        let app = XCUIApplication()
        app.launch()

        app.buttons["Form Screen"].tap()

        XCTAssertNotEqual(app.staticTexts["SPAN_ID"].label, "NO SPAN")
        let formScreenNavigationBar = app.navigationBars["Form Screen"]
        formScreenNavigationBar/*@START_MENU_TOKEN@*/.buttons["Test"]/*[[".otherElements[\"Test\"].buttons[\"Test\"]",".buttons[\"Test\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        XCTAssertEqual(app.staticTexts["SPAN_ID"].label, "NO SPAN")
    }
    
    func testTTID_TTFD_withTracedViewWaitForFullDisplay_shouldBeReported() {
        // -- Arrange --
        let app = XCUIApplication()
        app.launch()
        
        // -- Act --
        app.buttons["Show TTD"].tap()
        
        // -- Assert --
        // By pressing the button 'Show TTD', it will display the TTD info.
        // If the TTD info is not displayed, it was not reported, therefore the test should fail.
        XCTAssertEqual(app.staticTexts["TTDInfo"].label, "TTID and TTFD found")
    }

    func testTTID_TTFD_withDelayedFullDisplay_shouldReportTTDInfoOnlyAfterDelay() {
        // -- Arrange --
        // Launch the app and navigate to the delayed full display view.
        let app = XCUIApplication()
        app.launch()
        app.buttons["button.destination.full-display-deplayed"].tap()

        // Note: UI Tests can not directly access Sentry SDK data, therefore we
        // need to set the status in the UI and access it from there.
        let updateStatusButton = app.buttons["button.update-ttfd-ttid-status"]
        guard updateStatusButton.waitForExistence(timeout: 1) else {
            return XCTFail("Update status button not found")
        }
        // Switchs can only have two states: On or Off
        // Therefore we add an additional counter to check if the status has been updated.
        let statusRefreshCounter = app.staticTexts["label.status-refresh-counter"]
        guard statusRefreshCounter.waitForExistence(timeout: 1) else {
            return XCTFail("Status refresh counter not found")
        }
        XCTAssertEqual(statusRefreshCounter.label, "Status Refresh Counter: 0")
        let statusSwitchTTID = app.switches["check.ttid-reported"]
        guard statusSwitchTTID.waitForExistence(timeout: 1) else {
            return XCTFail("TTID status Switch not found")
        }
        XCTAssertEqual(statusSwitchTTID.value as? String, "0")
        let statusSwitchTTFD = app.switches["check.ttfd-reported"]
        guard statusSwitchTTFD.waitForExistence(timeout: 1) else {
            return XCTFail("TTFD status Switch not found")
        }
        XCTAssertEqual(statusSwitchTTID.value as? String, "0")

        // - Check Preconditions
        // Expect the initial content to appear immediately.
        let initialContent = app.staticTexts["content.initial"]
        guard initialContent.waitForExistence(timeout: 1) else {
            return XCTFail("Initial content not found")
        }

        // Confirm pre-condition that full content does not exist yet.
        let fullContent = app.staticTexts["content.delayed"]
        if fullContent.exists {
            return XCTFail("Delayed content should not exist yet")
        }

        // Verify TTID has been reported, but TTFD not yet.
        updateStatusButton.tap()
        XCTAssertEqual(statusRefreshCounter.label, "Status Refresh Counter: 1")
        XCTAssertEqual(statusSwitchTTID.value as? String, "1")
        XCTAssertEqual(statusSwitchTTFD.value as? String, "0")

        // -- Act --
        // Trigger the appearance of the delayed content
        let triggerButton = app.buttons["button.trigger-delayed-content"]
        guard triggerButton.waitForExistence(timeout: 1) else {
            return XCTFail("Trigger button not found")
        }
        triggerButton.tap()

        // -- Assert --
        // Verify TTFD is delayed and not reported yet.
        updateStatusButton.tap()
        XCTAssertEqual(statusRefreshCounter.label, "Status Refresh Counter: 2")
        XCTAssertEqual(statusSwitchTTID.value as? String, "1")
        XCTAssertEqual(statusSwitchTTFD.value as? String, "0")

        // Confirm that the full content eventually appears.
        guard fullContent.waitForExistence(timeout: 5) else {
            return XCTFail("Delayed content not found")
        }

        // Verify TTFD has been reported.
        updateStatusButton.tap()
        XCTAssertEqual(statusRefreshCounter.label, "Status Refresh Counter: 3")
        XCTAssertEqual(statusSwitchTTID.value as? String, "1")
        XCTAssertEqual(statusSwitchTTFD.value as? String, "1")
    }
}
