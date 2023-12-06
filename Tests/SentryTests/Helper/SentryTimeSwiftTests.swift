import Nimble
import XCTest

final class SentryTimeSwiftTests: XCTestCase {
    
    func testTimeIntervalToNanoseconds() {
        expect(timeIntervalToNanoseconds(0.0)) == UInt64(0)
        expect(timeIntervalToNanoseconds(0.5)) == UInt64(500_000_000)
        expect(timeIntervalToNanoseconds(1.0)) == UInt64(1_000_000_000)
        expect(timeIntervalToNanoseconds(1.123456789)) == UInt64(1_123_456_789)
        expect(timeIntervalToNanoseconds(123_456_789.123456)) == UInt64(123_456_789_123_456_000)
    }

    func testNanosecondsToTimeInterval() {
        expect(nanosecondsToTimeInterval(0)).to(beCloseTo(0.0, within: 1e-9))
        expect(nanosecondsToTimeInterval(500_000_000)).to(beCloseTo(0.5, within: 1e-9))
        expect(nanosecondsToTimeInterval(1_000_000_000)).to(beCloseTo(1.0, within: 1e-9))
        expect(nanosecondsToTimeInterval(1_123_456_789)).to(beCloseTo(1.123456789, within: 1e-9))
        expect(nanosecondsToTimeInterval(123_456_789_123_456_000)).to(beCloseTo(123_456_789.123456, within: 1e-9))
    }
}
