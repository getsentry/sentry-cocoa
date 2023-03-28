import XCTest

extension XCUIElement {
    func waitForExistence(_ message: String) {
        XCTAssertTrue(self.waitForExistence(timeout: TimeInterval(10)), message)
    }

    func afterWaitingForExistence(_ failureMessage: String) -> XCUIElement {
        waitForExistence(failureMessage)
        return self
    }
}
