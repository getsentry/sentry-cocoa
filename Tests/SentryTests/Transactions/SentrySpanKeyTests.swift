@testable import Sentry
import XCTest

class SentrySpanDataKeyTests: XCTestCase {
    func testFileSize_shouldBeExpectedValue() {
        XCTAssertEqual(SentrySpanDataKeyFileSize, "file.size")
    }

    func testFilePath_shouldBeExpectedValue() {
        XCTAssertEqual(SentrySpanDataKeyFilePath, "file.path")
    }
}
