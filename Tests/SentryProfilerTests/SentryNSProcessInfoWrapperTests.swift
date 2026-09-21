@_spi(Private) @testable import SentryTestUtils
import XCTest

#if !SWIFT_PACKAGE || !SDK_V10
class SentryNSProcessInfoWrapperTests: XCTestCase {
    private struct Fixture {
        lazy var processInfoWrapper = MockSentryProcessInfo()
    }
    lazy private var fixture = Fixture()

    func testProcessorCount() {
        XCTAssertTrue((0...Int.max).contains(fixture.processInfoWrapper.processorCount))
    }
}
#endif
