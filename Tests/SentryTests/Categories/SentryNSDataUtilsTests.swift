import Sentry
import XCTest

final class SentryNSDataUtilsTests: XCTestCase {

    func testCRC32OfString_SameString_ReturnsSameResult() throws {
        let result1 = sentry_crc32ofString("test-string")
        let result2 = sentry_crc32ofString("test-string")
        XCTAssertEqual(result1, result2)
    }
    
    func testCRC32OfString_DifferentString_ReturnsDifferentResult() throws {
        let result1 = sentry_crc32ofString("test-string")
        let result2 = sentry_crc32ofString("test-string1")
        XCTAssertNotEqual(result1, result2)
    }

}
