import XCTest

class SentryByteCountFormatterTests: XCTestCase {

    private let midRangeMultiplier: UInt = 512
    private let maxValueOffset: UInt = 1_024 - 1

    func testBytesDescription() {
        // -- Arrange --
        let baseValue: UInt = 1
        let unitName = "bytes"

        // -- Act --
        let singleUnitResult = SentryByteCountFormatter.bytesCountDescription(baseValue)
        let midRangeResult = SentryByteCountFormatter.bytesCountDescription(baseValue * midRangeMultiplier)
        let maxValueResult = SentryByteCountFormatter.bytesCountDescription(baseValue * maxValueOffset)

        // -- Assert --
        XCTAssertEqual("1 \(unitName)", singleUnitResult)
        XCTAssertEqual("512 \(unitName)", midRangeResult)
        XCTAssertEqual("1,023 \(unitName)", maxValueResult)
    }

    func testKBDescription() {
        // -- Arrange --
        let baseValue: UInt = 1_024
        let unitName = "KB"

        // -- Act --
        let singleUnitResult = SentryByteCountFormatter.bytesCountDescription(baseValue)
        let midRangeResult = SentryByteCountFormatter.bytesCountDescription(baseValue * midRangeMultiplier)
        let maxValueResult = SentryByteCountFormatter.bytesCountDescription(baseValue * maxValueOffset)

        // -- Assert --
        XCTAssertEqual("1 \(unitName)", singleUnitResult)
        XCTAssertEqual("512 \(unitName)", midRangeResult)
        XCTAssertEqual("1,023 \(unitName)", maxValueResult)
    }

    func testMBDescription() {
        // -- Arrange --
        let baseValue: UInt = 1_024 * 1_024
        let unitName = "MB"

        // -- Act --
        let singleUnitResult = SentryByteCountFormatter.bytesCountDescription(baseValue)
        let midRangeResult = SentryByteCountFormatter.bytesCountDescription(baseValue * midRangeMultiplier)
        let maxValueResult = SentryByteCountFormatter.bytesCountDescription(baseValue * maxValueOffset)

        // -- Assert --
        XCTAssertEqual("1 \(unitName)", singleUnitResult)
        XCTAssertEqual("512 \(unitName)", midRangeResult)
        XCTAssertEqual("1,023 \(unitName)", maxValueResult)
    }

    func testGBDescription() {
        // -- Arrange --
        let baseValue: UInt = 1_024 * 1_024 * 1_024
        let unitName = "GB"

        // -- Act --
        let singleUnitResult = SentryByteCountFormatter.bytesCountDescription(baseValue)
        let midRangeResult = SentryByteCountFormatter.bytesCountDescription(baseValue * midRangeMultiplier)
        let maxValueResult = SentryByteCountFormatter.bytesCountDescription(baseValue * maxValueOffset)

        // -- Assert --
        XCTAssertEqual("1 \(unitName)", singleUnitResult)
        XCTAssertEqual("512 \(unitName)", midRangeResult)
        XCTAssertEqual("1,023 \(unitName)", maxValueResult)
    }

}
