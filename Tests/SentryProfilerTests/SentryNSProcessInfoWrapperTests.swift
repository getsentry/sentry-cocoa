@_spi(Private) @testable import SentryTestUtils
import XCTest

class SentryNSProcessInfoWrapperTests: XCTestCase {
    private struct Fixture {
        lazy var processInfoWrapper = MockSentryProcessInfo()
    }
    lazy private var fixture = Fixture()

    func testProcessorCount() {
        XCTAssert((0...Int.max).contains(fixture.processInfoWrapper.processorCount))
    }
}
