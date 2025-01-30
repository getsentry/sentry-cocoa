import XCTest

class SentryNSProcessInfoWrapperTests: XCTestCase {
    private struct Fixture {
        lazy var processInfoWrapper = SentryNSProcessInfoWrapper()
    }
    lazy private var fixture = Fixture()

    func testProcessorCount() {
        XCTAssert((0...UInt.max).contains(fixture.processInfoWrapper.processorCount))
    }
}
