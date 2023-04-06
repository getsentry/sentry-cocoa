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

    func testFormatHexAddressPerformance() {
        measure {
            for _ in 0..<1_000 {
                sentry_formatHexAddress(arc4random() as NSNumber)
            }
        }
    }
}
