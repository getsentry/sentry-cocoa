#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
import _SentryPrivate
import SentryObjCInternal
import SentryTestsObjCHelpers
#else
@testable import Sentry
#endif
import XCTest

class SentrySpanDataKeyTests: XCTestCase {
    func testFileSize_shouldBeExpectedValue() {
        XCTAssertEqual(SentrySpanDataKeyFileSize, "file.size")
    }

    func testFilePath_shouldBeExpectedValue() {
        XCTAssertEqual(SentrySpanDataKeyFilePath, "file.path")
    }
}
