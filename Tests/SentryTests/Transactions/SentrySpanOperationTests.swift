@testable import Sentry
import XCTest

class SentrySpanOperationTests: XCTestCase {

    /// This test asserts that the constant matches the SDK specification.
    func testFileRead_shouldBeExpectedValue() {
        XCTAssertEqual(SentrySpanOperation.fileRead, "file.read")
    }

    /// This test asserts that the constant matches the SDK specification.
    func testFileWrite_shouldBeExpectedValue() {
        XCTAssertEqual(SentrySpanOperation.fileWrite, "file.write")
    }
}
