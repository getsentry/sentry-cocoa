import XCTest

class SentrySystemWrapperTests: XCTestCase {
    struct Fixture {
        lazy var systemWrapper = SentrySystemWrapper()
    }
    lazy var fixture = Fixture()

    func testCPUUsageReportsData() throws {
        XCTAssertNoThrow({
            let cpuUsages = try self.fixture.systemWrapper.cpuUsagePerCore()
            XCTAssertGreaterThan(cpuUsages.count, 0)
            let range = 0.0 ... 100.0
            cpuUsages.forEach {
                XCTAssert(range.contains($0.doubleValue))
            }
        })
    }

    func testMemoryFootprint() {
        let error: NSErrorPointer = nil
        let memoryFootprint = fixture.systemWrapper.memoryFootprintBytes(error)
        XCTAssertNil(error?.pointee)
        XCTAssert((0...UINT64_MAX).contains(memoryFootprint))
    }
}
