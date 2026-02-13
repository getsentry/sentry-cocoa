@_spi(Private) import Sentry
import XCTest

class SentryByteCountFormatterTests: XCTestCase {

    private let halfKbSize: UInt = 512
    private let kbSize: UInt = 1_024

    func testBytesCountDescription_whenSingleByte_shouldReturnOneByte() {
        // -- Arrange --
        let value: UInt = 1

        // -- Act --
        let result = SentryByteCountFormatter.bytesCountDescription(value)

        // -- Assert --
        XCTAssertEqual("1 bytes", result)
    }

    func testBytesCountDescription_whenMidRangeBytes_shouldReturnBytesWithValue() {
        // -- Arrange --
        let value: UInt = halfKbSize

        // -- Act --
        let result = SentryByteCountFormatter.bytesCountDescription(value)

        // -- Assert --
        XCTAssertEqual("512 bytes", result)
    }

    func testBytesCountDescription_whenMaxBytes_shouldReturnMaxBytesBeforeKB() {
        // -- Arrange --
        let value: UInt = kbSize - 1

        // -- Act --
        let result = SentryByteCountFormatter.bytesCountDescription(value)

        // -- Assert --
        XCTAssertEqual("1,023 bytes", result)
    }

    func testBytesCountDescription_whenSingleKilobyte_shouldReturnOneKB() {
        // -- Arrange --
        let value: UInt = kbSize

        // -- Act --
        let result = SentryByteCountFormatter.bytesCountDescription(value)

        // -- Assert --
        XCTAssertEqual("1 KB", result)
    }

    func testBytesCountDescription_whenMidRangeKilobytes_shouldReturnKBWithValue() {
        // -- Arrange --
        let value: UInt = kbSize * halfKbSize

        // -- Act --
        let result = SentryByteCountFormatter.bytesCountDescription(value)

        // -- Assert --
        XCTAssertEqual("512 KB", result)
    }

    func testBytesCountDescription_whenMaxKilobytes_shouldReturnMaxKBBeforeMB() {
        // -- Arrange --
        let value: UInt = kbSize * kbSize - 1

        // -- Act --
        let result = SentryByteCountFormatter.bytesCountDescription(value)

        // -- Assert --
        XCTAssertEqual("1,023 KB", result)
    }

    func testBytesCountDescription_whenSingleMegabyte_shouldReturnOneMB() {
        // -- Arrange --
        let value: UInt = kbSize * kbSize

        // -- Act --
        let result = SentryByteCountFormatter.bytesCountDescription(value)

        // -- Assert --
        XCTAssertEqual("1 MB", result)
    }

    func testBytesCountDescription_whenMidRangeMegabytes_shouldReturnMBWithValue() {
        // -- Arrange --
        let value: UInt = kbSize * kbSize * halfKbSize

        // -- Act --
        let result = SentryByteCountFormatter.bytesCountDescription(value)

        // -- Assert --
        XCTAssertEqual("512 MB", result)
    }

    func testBytesCountDescription_whenMaxMegabytes_shouldReturnMaxMBBeforeGB() {
        // -- Arrange --
        let value: UInt = kbSize * kbSize * kbSize - 1

        // -- Act --
        let result = SentryByteCountFormatter.bytesCountDescription(value)

        // -- Assert --
        XCTAssertEqual("1,023 MB", result)
    }

    func testBytesCountDescription_whenSingleGigabyte_shouldReturnOneGB() {
        // -- Arrange --
        let value: UInt = kbSize * kbSize * kbSize

        // -- Act --
        let result = SentryByteCountFormatter.bytesCountDescription(value)

        // -- Assert --
        XCTAssertEqual("1 GB", result)
    }

    func testBytesCountDescription_whenMidRangeGigabytes_shouldReturnGBWithValue() {
        // -- Arrange --
        let value: UInt = kbSize * kbSize * kbSize * halfKbSize

        // -- Act --
        let result = SentryByteCountFormatter.bytesCountDescription(value)

        // -- Assert --
        XCTAssertEqual("512 GB", result)
    }

    func testBytesCountDescription_whenMaxGigabytes_shouldReturnMaxGBBeforeTB() {
        // -- Arrange --
        let value: UInt = kbSize * kbSize * kbSize * kbSize - 1

        // -- Act --
        let result = SentryByteCountFormatter.bytesCountDescription(value)

        // -- Assert --
        XCTAssertEqual("1,023 GB", result)
    }

}
