import XCTest

class SentryHintTests: XCTestCase {

    func testInit_shouldHaveNilProperties() {
        // -- Arrange --
        let hint = Hint()

        // -- Assert --
        XCTAssertNil(hint.originalError)
        XCTAssertNil(hint.originalException)
        XCTAssertTrue(hint.attachments.isEmpty)
    }

    func testInitWithError_shouldSetOriginalError() {
        // -- Arrange --
        let error = NSError(domain: "test", code: 1)

        // -- Act --
        let hint = Hint(error: error)

        // -- Assert --
        let resultError = hint.originalError as NSError?
        XCTAssertEqual(resultError, error)
        XCTAssertNil(hint.originalException)
        XCTAssertTrue(hint.attachments.isEmpty)
    }

    func testInitWithException_shouldSetOriginalException() {
        // -- Arrange --
        let exception = NSException(name: .genericException, reason: "test")

        // -- Act --
        let hint = Hint(exception: exception)

        // -- Assert --
        XCTAssertNil(hint.originalError)
        XCTAssertEqual(hint.originalException, exception)
        XCTAssertTrue(hint.attachments.isEmpty)
    }

    func testSetAndGetHintValue() {
        // -- Arrange --
        let hint = Hint()

        // -- Act --
        hint.setHintValue("value", forKey: "key")

        // -- Assert --
        XCTAssertEqual(hint.hintValue(forKey: "key") as? String, "value")
    }

    func testHintValue_whenKeyNotSet_shouldReturnNil() {
        // -- Arrange --
        let hint = Hint()

        // -- Assert --
        XCTAssertNil(hint.hintValue(forKey: "missing"))
    }

    func testRemoveHintValue() {
        // -- Arrange --
        let hint = Hint()
        hint.setHintValue("value", forKey: "key")

        // -- Act --
        hint.removeHintValue(forKey: "key")

        // -- Assert --
        XCTAssertNil(hint.hintValue(forKey: "key"))
    }

    func testRemoveHintValue_whenKeyNotSet_shouldNotCrash() {
        // -- Arrange --
        let hint = Hint()

        // -- Act --
        hint.removeHintValue(forKey: "nonexistent")

        // -- Assert --
        XCTAssertNil(hint.hintValue(forKey: "nonexistent"))
    }

    func testSetHintValue_shouldOverwriteExistingValue() {
        // -- Arrange --
        let hint = Hint()
        hint.setHintValue("old", forKey: "key")

        // -- Act --
        hint.setHintValue("new", forKey: "key")

        // -- Assert --
        XCTAssertEqual(hint.hintValue(forKey: "key") as? String, "new")
    }

    func testAttachments_shouldBeSettable() {
        // -- Arrange --
        let hint = Hint()
        let attachment = Attachment(data: Data("test".utf8), filename: "test.txt")

        // -- Act --
        hint.attachments = [attachment]

        // -- Assert --
        XCTAssertEqual(hint.attachments.count, 1)
        XCTAssertEqual(hint.attachments.first?.filename, "test.txt")
    }

    func testOriginalError_shouldBeSettable() {
        // -- Arrange --
        let hint = Hint()
        let error = NSError(domain: "test", code: 42)

        // -- Act --
        hint.originalError = error

        // -- Assert --
        let resultError = hint.originalError as NSError?
        XCTAssertEqual(resultError, error)
    }

    func testOriginalException_shouldBeSettable() {
        // -- Arrange --
        let hint = Hint()
        let exception = NSException(name: .genericException, reason: "reason")

        // -- Act --
        hint.originalException = exception

        // -- Assert --
        XCTAssertEqual(hint.originalException, exception)
    }

    func testThreadSafety() {
        // -- Arrange --
        let hint = Hint()
        let iterations = 100
        let expectation = expectation(description: "concurrent access")
        expectation.expectedFulfillmentCount = iterations

        // -- Act --
        for i in 0..<iterations {
            DispatchQueue.global().async {
                hint.setHintValue(i, forKey: "key-\(i)")
                _ = hint.hintValue(forKey: "key-\(i)")
                hint.originalError = NSError(domain: "test", code: i)
                _ = hint.originalError
                hint.attachments = [Attachment(data: Data("test".utf8), filename: "f\(i).txt")]
                _ = hint.attachments
                expectation.fulfill()
            }
        }

        // -- Assert --
        wait(for: [expectation], timeout: 5)
    }
}
