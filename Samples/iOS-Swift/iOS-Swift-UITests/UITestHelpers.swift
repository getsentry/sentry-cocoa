import XCTest

extension XCUIElement {
    func waitForExistence(_ message: String) {
        XCTAssertTrue(self.waitForExistence(timeout: TimeInterval(10)), message)
    }
    
    func waitForNonExistence(_ message: String) {
        var retry = 0
        while self.exists && retry < 10 {
            retry += 1
            Thread.sleep(forTimeInterval: 1)
        }
        
        if retry == 10 {
            XCTFail(message)
        }
    }

    func afterWaitingForExistence(_ failureMessage: String) -> XCUIElement {
        waitForExistence(failureMessage)
        return self
    }
}
