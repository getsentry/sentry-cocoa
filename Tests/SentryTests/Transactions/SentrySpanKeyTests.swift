@testable import Sentry
import XCTest

class SentrySpanKeyTests: XCTestCase {
    func testAppLifecycle_shouldBeExpectedValue() {
        XCTAssertEqual(SentrySpanKey.fileSize, "file.size")
    }
}
