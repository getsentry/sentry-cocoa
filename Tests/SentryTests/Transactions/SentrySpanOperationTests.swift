@testable import Sentry
import XCTest

class SentrySpanOperationTests: XCTestCase {

    func testFileRead_shouldBeExpectedValue() {
        XCTAssertEqual(SentrySpanOperation.fileRead, "file.read")
    }
    func testFileWrite_shouldBeExpectedValue() {
        XCTAssertEqual(SentrySpanOperation.fileWrite, "file.write")
    }
}
