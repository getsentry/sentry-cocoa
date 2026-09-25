import XCTest

final class UITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureMessage_whenStaticallyLinkedWithoutObjC_shouldReachBeforeSend() {
        // -- Arrange --
        let app = XCUIApplication()
        app.launch()
        let captureButton = app.buttons["capture-message"]
        XCTAssertTrue(captureButton.waitForExistence(timeout: 10))

        // -- Act --
        captureButton.tap()

        // -- Assert --
        let eventPrepared = expectation(
            for: NSPredicate(format: "label == %@", "Event prepared"),
            evaluatedWith: app.staticTexts["capture-result"]
        )
        wait(for: [eventPrepared], timeout: 10)
    }
}
