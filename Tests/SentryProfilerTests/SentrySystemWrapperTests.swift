import XCTest

class SentrySystemWrapperTests: XCTestCase {
    private struct Fixture {
        lazy var systemWrapper = SentrySystemWrapper()
    }
    lazy private var fixture = Fixture()

    func testCPUUsageReportsData() throws {
        XCTAssertNoThrow({
            let cpuUsage = try XCTUnwrap(self.fixture.systemWrapper.cpuUsage())
            XCTAssert((0.0 ... 100.0).contains(cpuUsage.doubleValue))
        })
    }

    func testMemoryFootprint() {
        let error: NSErrorPointer = nil
        let memoryFootprint = fixture.systemWrapper.memoryFootprintBytes(error)
        XCTAssertNil(error?.pointee)
        XCTAssert((0...UINT64_MAX).contains(memoryFootprint))
    }
}
