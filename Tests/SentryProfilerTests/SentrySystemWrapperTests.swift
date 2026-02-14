@_spi(Private) @testable import Sentry
@_spi(Private) @testable import SentryTestUtils
import XCTest

#if os(iOS) || os(macOS)
class SentrySystemWrapperTests: XCTestCase {
    private struct Fixture {
        lazy var systemWrapper = SentrySystemWrapper(processorCount: 4)
        lazy var testSystemWrapper = TestSentrySystemWrapper()
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

    func testMemoryFootprint_whenErrorOverride_shouldSetErrorAndReturnZero() {
        // -- Arrange --
        let wrapper = fixture.testSystemWrapper
        let expectedError = NSError(domain: "test-error", code: 42)
        wrapper.overrides.memoryFootprintError = expectedError

        var error: NSError?

        // -- Act --
        let result = wrapper.memoryFootprintBytes(&error)

        // -- Assert --
        XCTAssertEqual(result, 0)
        XCTAssertEqual(error?.domain, expectedError.domain)
        XCTAssertEqual(error?.code, expectedError.code)
    }

    func testMemoryFootprint_whenBytesOverride_shouldReturnOverride() {
        // -- Arrange --
        let wrapper = fixture.testSystemWrapper
        let expectedBytes: mach_vm_size_t = 99_999
        wrapper.overrides.memoryFootprintBytes = expectedBytes

        var error: NSError?

        // -- Act --
        let result = wrapper.memoryFootprintBytes(&error)

        // -- Assert --
        XCTAssertEqual(result, expectedBytes)
        XCTAssertNil(error)
    }

    func testCPUUsage_whenErrorOverride_shouldThrow() {
        // -- Arrange --
        let wrapper = fixture.testSystemWrapper
        let expectedError = NSError(domain: "test-error", code: 1)
        wrapper.overrides.cpuUsageError = expectedError

        // -- Act & Assert --
        XCTAssertThrowsError(try wrapper.cpuUsage()) { thrownError in
            XCTAssertEqual((thrownError as NSError).domain, expectedError.domain)
            XCTAssertEqual((thrownError as NSError).code, expectedError.code)
        }
    }

    func testCPUUsage_whenUsageOverride_shouldReturnOverride() throws {
        // -- Arrange --
        let wrapper = fixture.testSystemWrapper
        let expectedUsage = NSNumber(value: 42.5)
        wrapper.overrides.cpuUsage = expectedUsage

        // -- Act --
        let result = try wrapper.cpuUsage()

        // -- Assert --
        XCTAssertEqual(result, expectedUsage)
    }

#if arch(arm64) || arch(arm)
    func testCPUEnergyUsageReportsData() throws {
        let cpuEnergyUsage = try fixture.systemWrapper.cpuEnergyUsage()
        XCTAssertGreaterThanOrEqual(cpuEnergyUsage.uintValue, 0)
    }

    func testCPUEnergyUsage_whenErrorOverride_shouldThrow() {
        // -- Arrange --
        let wrapper = fixture.testSystemWrapper
        let expectedError = NSError(domain: "test-error", code: 2)
        wrapper.overrides.cpuEnergyUsageError = expectedError

        // -- Act & Assert --
        XCTAssertThrowsError(try wrapper.cpuEnergyUsage()) { thrownError in
            XCTAssertEqual((thrownError as NSError).domain, expectedError.domain)
            XCTAssertEqual((thrownError as NSError).code, expectedError.code)
        }
    }

    func testCPUEnergyUsage_whenUsageOverride_shouldReturnOverride() throws {
        // -- Arrange --
        let wrapper = fixture.testSystemWrapper
        let expectedEnergy = NSNumber(value: 1_000_000)
        wrapper.overrides.cpuEnergyUsage = expectedEnergy

        // -- Act --
        let result = try wrapper.cpuEnergyUsage()

        // -- Assert --
        XCTAssertEqual(result, expectedEnergy)
    }
#endif
}
#endif // os(iOS) || os(macOS)
