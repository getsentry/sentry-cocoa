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

    func testParseHexAddress_Zero_ReturnsZero() {
        XCTAssertEqual(UInt64(0), sentry_UInt64ForHexAddress("0"))
    }

    func testParseHexAddress_Zero0x_ReturnsZero() {
        XCTAssertEqual(UInt64(0), sentry_UInt64ForHexAddress("0x0"))
    }

    func testParseHexAddress_One_ReturnsOne() {
        XCTAssertEqual(UInt64(1), sentry_UInt64ForHexAddress("0x1"))
    }

    func testParseHexAddress_F_Returns15() {
        XCTAssertEqual(UInt64(15), sentry_UInt64ForHexAddress("0xF"))
    }

    func testParseHexAddress_UInt64Max_ReturnsUInt64Max() {
        let uIntMaxHexAddress = "0x18446744073709551615"
        XCTAssertEqual(UInt64.max, sentry_UInt64ForHexAddress(uIntMaxHexAddress))
    }

    func testParseHexAddress_UInt64MaxPlusOne_ReturnsUInt64Max() {
        let uIntMaxHexAddressPlusOne = "0x18446744073709551616"
        XCTAssertEqual(UInt64.max, sentry_UInt64ForHexAddress(uIntMaxHexAddressPlusOne))
    }

    func testParseHexAddress_Overflow_ReturnsUInt64Max() {
        let uIntMaxVastOverflow = "0xFFFFFFFFFFFFFFFFFFFF"
        XCTAssertEqual(UInt64.max, sentry_UInt64ForHexAddress(uIntMaxVastOverflow))
    }

    func testParseHexAddress_G_Returns0() {
        XCTAssertEqual(UInt64(0), sentry_UInt64ForHexAddress("0xG"))
    }

    func testParseHexAddress_Garbage_Returns0() {
        XCTAssertEqual(UInt64(0), sentry_UInt64ForHexAddress("hello"))
    }

    func testParseHexAddress_MinusOne_Returns0() {
        XCTAssertEqual(UInt64(0), sentry_UInt64ForHexAddress("-1"))
    }

    func testParseHexAddress_WithLeading0x_ReturnsCorrectValue() {
        XCTAssertEqual(UInt64(1_234_345), sentry_UInt64ForHexAddress("0x000000000012d5a9") )
    }

    func testParseHexAddress_WithLeading0X_ReturnsCorrectValue() {
        XCTAssertEqual(UInt64(1_234_345), sentry_UInt64ForHexAddress("0X000000000012d5a9") )
    }

    func testParseHexAddress_WithoutLeading0x_ReturnsCorrectValue() {
        XCTAssertEqual(UInt64(1_234_345), sentry_UInt64ForHexAddress("000000000012d5a9"))
    }
}
