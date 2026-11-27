import SentryNativeUtils
import SentryNativeUtilsTestSupport
import XCTest

final class SentryTimeTests: XCTestCase {
    func testDuration() {
        // -- Arrange --
        // The native implementation asserts for invalid inputs in Debug. Ignore assertions only
        // here to verify its release behavior without disabling assertions for the other tests.
        SentryTimeTestsAssertionHandler.performIgnoringAssertions {
            // -- Act / Assert --
            XCTAssertEqual(getDurationNs(0, 1), 1)
            XCTAssertEqual(getDurationNs(1, 1), 0)
            XCTAssertEqual(getDurationNs(1, 7), 6)
            XCTAssertEqual(getDurationNs(0, UInt64.max), UInt64.max)

            // Inputs that are not chronologically ordered always return zero.
            XCTAssertEqual(getDurationNs(1, 0), 0)
            XCTAssertEqual(getDurationNs(UInt64.max, 0), 0)

            // Negative inputs wrap around when converted to unsigned integers.
            let negativeOne = UInt64(truncatingIfNeeded: -1)
            let negativeMax = UInt64(0) &- UInt64.max
            XCTAssertEqual(getDurationNs(0, negativeOne), UInt64.max)
            XCTAssertEqual(getDurationNs(negativeOne, 0), 0)
            XCTAssertEqual(getDurationNs(negativeOne, negativeOne), 0)
            XCTAssertEqual(getDurationNs(0, negativeMax), 1)
            XCTAssertEqual(getDurationNs(negativeMax, 0), 0)
        }
    }

    func testChronologicOrderCheck() {
        // -- Act / Assert --
        XCTAssertTrue(orderedChronologically(0, 1))
        XCTAssertTrue(orderedChronologically(0, 5_365))
        XCTAssertTrue(orderedChronologically(24, 7_532_564))
        XCTAssertFalse(orderedChronologically(1, 0))
        XCTAssertFalse(orderedChronologically(32_431, 53))

        // Equal timestamps are in chronological order.
        XCTAssertTrue(orderedChronologically(0, 0))
        XCTAssertTrue(orderedChronologically(1, 1))
        XCTAssertTrue(orderedChronologically(UInt64.max, UInt64.max))

        // Negative inputs wrap around when converted to unsigned integers.
        let negativeOne = UInt64(truncatingIfNeeded: -1)
        let negativeMax = UInt64(0) &- UInt64.max
        XCTAssertTrue(orderedChronologically(0, negativeOne))
        XCTAssertFalse(orderedChronologically(UInt64.max, negativeMax))
        XCTAssertFalse(orderedChronologically(negativeOne, 0))
        XCTAssertTrue(orderedChronologically(negativeMax, UInt64.max))
        XCTAssertTrue(orderedChronologically(negativeOne, negativeOne))
        XCTAssertTrue(orderedChronologically(negativeMax, negativeMax))
    }

    func testTimeIntervalToNanoseconds() {
        // -- Act / Assert --
        XCTAssertEqual(timeIntervalToNanoseconds(0.0), UInt64(0))
        XCTAssertEqual(timeIntervalToNanoseconds(0.5), UInt64(500_000_000))
        XCTAssertEqual(timeIntervalToNanoseconds(1.0), UInt64(1_000_000_000))
        XCTAssertEqual(timeIntervalToNanoseconds(1.123456789), UInt64(1_123_456_789))
        XCTAssertEqual(timeIntervalToNanoseconds(123_456_789.123456), UInt64(123_456_789_123_456_000))
    }

    func testNanosecondsToTimeInterval() {
        // -- Act / Assert --
        XCTAssertEqual(nanosecondsToTimeInterval(0), 0.0, accuracy: 1e-9)
        XCTAssertEqual(nanosecondsToTimeInterval(500_000_000), 0.5, accuracy: 1e-9)
        XCTAssertEqual(nanosecondsToTimeInterval(1_000_000_000), 1.0, accuracy: 1e-9)
        XCTAssertEqual(nanosecondsToTimeInterval(1_123_456_789), 1.123456789, accuracy: 1e-9)
        XCTAssertEqual(nanosecondsToTimeInterval(123_456_789_123_456_000), 123_456_789.123456, accuracy: 1e-9)
    }
}
