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

#if SDK_V10
    func testCPUUsage_underLoad_shouldReturnNormalizedPercent() throws {
        var keepRunning = true

        let threads = (0..<4).map { _ in
            Thread {
                var x: Double = 1.0
                while keepRunning {
                    for _ in 0..<10_000 {
                        x = sin(x) + 1.0
                    }
                }
                _ = x
            }
        }
        threads.forEach { $0.start() }

        Thread.sleep(forTimeInterval: 0.2)

        let cpuUsage = try XCTUnwrap(fixture.systemWrapper.cpuUsage())
        keepRunning = false

        XCTAssertGreaterThanOrEqual(cpuUsage.doubleValue, 0.0)
        XCTAssertLessThanOrEqual(cpuUsage.doubleValue, 100.0)
    }
#endif

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
