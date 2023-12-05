import Nimble
import XCTest

final class SentryTimeSwiftTests: XCTestCase {
    
    func testTimeIntervalToNanoseconds() {
        expect(timeIntervalToNanoseconds(0.0)) == UInt64(0)
        expect(timeIntervalToNanoseconds(0.5)) == UInt64(500_000_000)
        expect(timeIntervalToNanoseconds(1.0)) == UInt64(1_000_000_000)
        expect(timeIntervalToNanoseconds(18_446_744_073.709553)) == UInt64.max
    }

    func testNanosecondsToTimeInterval() {
        expect(nanosecondsToTimeInterval(0)).to(beCloseTo(0.0, within: 1e-9))
        expect(nanosecondsToTimeInterval(500_000_000)).to(beCloseTo(0.5, within: 1e-9))
        expect(nanosecondsToTimeInterval(1_000_000_000)).to(beCloseTo(1.0, within: 1e-9))
        expect(nanosecondsToTimeInterval(UInt64.max - 1)).to(beCloseTo(18_446_744_073.709551614, within: 1e-9))
    }
}
