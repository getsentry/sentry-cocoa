import Foundation
import XCTest

#if os(iOS) || os(macOS)
class SentrySystemWrapperTests: XCTestCase {
    private struct Fixture {
        lazy var systemWrapper = SentrySystemWrapper(processorCount: 4)
    }
    lazy private var fixture = Fixture()

    func testCPUUsage_whenIdle_shouldReportNormalizedPercent() throws {
        let cpuUsage = try XCTUnwrap(fixture.systemWrapper.cpuUsage())

        XCTAssertTrue((0.0 ... 100.0).contains(cpuUsage.doubleValue))
    }

    func testNormalizeCPUUsage_shouldConvertMachScaleToPercentOfTotalCapacity() {
        XCTAssertEqual(SentrySystemWrapper.normalizeCPUUsage(1_000, processorCount: 4), 25.0, accuracy: 0.001)
        XCTAssertEqual(SentrySystemWrapper.normalizeCPUUsage(500, processorCount: 8), 6.25, accuracy: 0.001)
        XCTAssertEqual(SentrySystemWrapper.normalizeCPUUsage(1_000, processorCount: 10), 10.0, accuracy: 0.001)
    }

    func testMemoryFootprint() {
        let error: NSErrorPointer = nil
        let memoryFootprint = fixture.systemWrapper.memoryFootprintBytes(error)
        XCTAssertNil(error?.pointee)
        XCTAssertTrue((0...UINT64_MAX).contains(memoryFootprint))
    }
}
#endif // os(iOS) || os(macOS)
