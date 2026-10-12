#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@testable import Sentry
#endif
import _SentryPrivate
import XCTest

class SentrySpanDataKeyTests: XCTestCase {
    func testFileSize_shouldBeExpectedValue() {
        XCTAssertEqual(SentrySpanDataKeyFileSize, "file.size")
    }

    func testFilePath_shouldBeExpectedValue() {
        XCTAssertEqual(SentrySpanDataKeyFilePath, "file.path")
    }
}
