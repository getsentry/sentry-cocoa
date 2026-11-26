import XCTest

final class EnvelopeTest: XCTestCase {

    func testCorruptedEnvelope() throws {
        let app = XCUIApplication()

        app.launch()

        app.buttons["Write Corrupted Envelope"].tap()
        let errorMessageElement = app.staticTexts["errorMessage"]
        if errorMessageElement.exists {
            XCTFail("Writing corrupted envelope failed with \(errorMessageElement.label)")
        }

        app.buttons["Start SDK"].tap()

        XCTAssertTrue(app.staticTexts["Welcome!"].exists)
    }
}
