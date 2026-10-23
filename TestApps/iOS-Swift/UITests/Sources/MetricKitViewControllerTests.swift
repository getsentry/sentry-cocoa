import XCTest

class MetricKitViewControllerTests: BaseUITest {
    func testCatalogHang_whenTriggered_shouldReturnToResponsiveUI() {
        // -- Arrange --
        app.buttons["More"].tap()
        app.staticTexts["MetricKit"].tap()
        let button = app.buttons["Hang: Catalog Refresh (~4 s)"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))

        // -- Act --
        button.tap()

        // -- Assert --
        XCTAssertTrue(app.buttons["Hang: Checkout (~4 s)"].isHittable)
        app.buttons["Extra"].tap()
        XCTAssertTrue(app.buttons["TOPVCBTN"].waitForExistence(timeout: 5))
    }

    func testCheckoutHang_whenTriggered_shouldReturnToResponsiveUI() {
        // -- Arrange --
        app.buttons["More"].tap()
        app.staticTexts["MetricKit"].tap()
        let button = app.buttons["Hang: Checkout (~4 s)"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))

        // -- Act --
        button.tap()

        // -- Assert --
        XCTAssertTrue(app.buttons["Hang: Catalog Refresh (~4 s)"].isHittable)
        app.buttons["Extra"].tap()
        XCTAssertTrue(app.buttons["TOPVCBTN"].waitForExistence(timeout: 5))
    }
}
