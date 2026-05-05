import XCTest

#if os(iOS) || os(macOS)
class SentrySystemWrapperTests: XCTestCase {
    private struct Fixture {
        lazy var systemWrapper = SentrySystemWrapper(processorCount: 4)
    }
    lazy private var fixture = Fixture()

    // MARK: - cpuUsageWithError

    func testCPUUsage_shouldReturnNonNilValue() throws {
        let cpuUsage = try XCTUnwrap(fixture.systemWrapper.cpuUsage())
        XCTAssertGreaterThanOrEqual(cpuUsage.floatValue, 0.0)
    }

    func testCPUUsage_shouldNotThrow() throws {
        XCTAssertNotNil(try fixture.systemWrapper.cpuUsage())
    }

    // Error path for cpuUsageWithError: untestable — task_threads uses hardcoded
    // mach_task_self() which cannot be made to fail without resource exhaustion.

    // MARK: - memoryFootprintBytes

    func testMemoryFootprint_shouldReturnPositiveValue() {
        var error: NSError?
        let memoryFootprint = fixture.systemWrapper.memoryFootprintBytes(&error)
        XCTAssertNil(error)
        XCTAssertGreaterThan(memoryFootprint, 0)
    }

    // MARK: - cpuEnergyUsageWithError

#if arch(arm64)
    func testCPUEnergyUsage_shouldReturnNonNilValue() throws {
        let energyUsage = try XCTUnwrap(fixture.systemWrapper.cpuEnergyUsage())
        XCTAssertGreaterThanOrEqual(energyUsage.uint64Value, 0)
    }

    func testCPUEnergyUsage_shouldNotThrow() throws {
        XCTAssertNotNil(try fixture.systemWrapper.cpuEnergyUsage())
    }

    // Error path for cpuEnergyUsageWithError: untestable — task_info uses hardcoded
    // mach_task_self() which cannot be made to fail without resource exhaustion.
#endif // arch(arm64)
}
#endif // os(iOS) || os(macOS)
