@testable import Sentry
import XCTest

class SentrySpanDataKeyTests: XCTestCase {
    func testFileSize_shouldBeExpectedValue() {
        XCTAssertEqual(SentrySpanDataKey.fileSize, "file.size")
    }

    func testFilePath_shouldBeExpectedValue() {
        XCTAssertEqual(SentrySpanDataKey.filePath, "file.path")
    }
}
