import XCTest

final class SentryFormatterTests: XCTestCase {
    func testFormatHexAddress() {
        for (input, expected) in [
            (0x000000008e902bf0, "0x000000008e902bf0"),
            (0x000000008fd09c40, "0x000000008fd09c40"),
            (0x00000000945b1c00, "0x00000000945b1c00")
        ] {
            XCTAssertEqual(sentry_formatHexAddress(input as NSNumber), expected)
        }
    }

    func testStringForUInt64() {
        for (input, expected) in [
            (0, "0"),
            (1, "1"),
            (123_456, "123456"),
            (UInt64.max, "18446744073709551615")
        ] {
            XCTAssertEqual(sentry_stringForUInt64(UInt64(input)), expected)
        }
    }
    
    func testParseHexAddress() {
        XCTAssertEqual(0x000000008e902bf0, sentry_parseHexAddress("0x000000008e902bf0"))
        
        XCTAssertEqual(0x000000008e902bf0, sentry_parseHexAddress("0000000102cdb070"))
        
        let originalValue: UInt64 = 1_234_345
        let hexValue = sentry_formatHexAddressUInt64(1_234_345)
        XCTAssertEqual(originalValue, sentry_parseHexAddress(hexValue))
    }
    
}
