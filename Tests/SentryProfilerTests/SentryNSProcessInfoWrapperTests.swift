import XCTest

class SentryNSProcessInfoWrapperTests: XCTestCase {
    struct Fixture {
        lazy var processInfoWrapper = SentryNSProcessInfoWrapper()
    }
    lazy var fixture = Fixture()

    func testProcessorCount() {
        XCTAssert((0...UInt.max).contains(fixture.processInfoWrapper.processorCount))
    }
}
