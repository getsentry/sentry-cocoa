@testable import Sentry
import XCTest

class SentrySpanKeyTests: XCTestCase {
    func testFileSize_shouldBeExpectedValue() {
        XCTAssertEqual(SentrySpanKey.fileSize, "file.size")
    }

    func testFilePath_shouldBeExpectedValue() {
        XCTAssertEqual(SentrySpanKey.filePath, "file.path")
    }
}
