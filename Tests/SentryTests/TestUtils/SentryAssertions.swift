import XCTest

/**
 * Asserts two values containing json as data are equal.
 */
func assertJsonIsEqual(actual: Data, expected: Data) {
    let actualAsString = String(data: actual, encoding: .utf8) ?? ""
    let expectedAsString = String(data: expected, encoding: .utf8) ?? ""
    
    XCTAssertTrue(actualAsString.sorted() == expectedAsString.sorted(), "\(actualAsString) is not equal to \(expectedAsString)")
}

func assertArrayEquals(expected: [String]?, actual: [String]?) {
    XCTAssertEqual(expected?.sorted(), actual?.sorted())
}

extension SentryId {
    func assertIsEmpty() {
        XCTAssertEqual(SentryId.empty, self)
    }
    
    func assertIsNotEmpty() {
        XCTAssertNotEqual(SentryId.empty, self)
    }
}
