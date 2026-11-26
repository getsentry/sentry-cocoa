#if SWIFT_PACKAGE
#if !SDK_V10
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
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
