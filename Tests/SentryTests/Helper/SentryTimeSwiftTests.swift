import XCTest

final class SentryTimeSwiftTests: XCTestCase {
    
    func testTimeIntervalToNanoseconds() {
        XCTAssertEqual(timeIntervalToNanoseconds(0.0), UInt64(0))
        XCTAssertEqual(timeIntervalToNanoseconds(0.5), UInt64(500_000_000))
        XCTAssertEqual(timeIntervalToNanoseconds(1.0), UInt64(1_000_000_000))
        XCTAssertEqual(timeIntervalToNanoseconds(1.123456789), UInt64(1_123_456_789))
        XCTAssertEqual(timeIntervalToNanoseconds(123_456_789.123456), UInt64(123_456_789_123_456_000))
    }

    func testNanosecondsToTimeInterval() {
        XCTAssertEqual(nanosecondsToTimeInterval(0), 0.0, accuracy: 1e-9)
        XCTAssertEqual(nanosecondsToTimeInterval(500_000_000), 0.5, accuracy: 1e-9)
        XCTAssertEqual(nanosecondsToTimeInterval(1_000_000_000), 1.0, accuracy: 1e-9)
        XCTAssertEqual(nanosecondsToTimeInterval(1_123_456_789), 1.123456789, accuracy: 1e-9)
        XCTAssertEqual(nanosecondsToTimeInterval(123_456_789_123_456_000), 123_456_789.123456, accuracy: 1e-9)
    }
}
