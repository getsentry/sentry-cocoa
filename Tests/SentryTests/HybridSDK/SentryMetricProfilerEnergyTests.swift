#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
@_spi(Private) @testable import SentryTestUtils
import _SentryPrivate
import XCTest

#if (os(iOS) || os(macOS)) && (arch(arm) || arch(arm64))
final class SentryMetricProfilerEnergyTests: XCTestCase {
    private struct Fixture {
        let date = TestCurrentDateProvider()
        let system = TestSentrySystemWrapper()

        init() {
            date.setDate(date: Date(timeIntervalSince1970: 1_000))
            SentryDependencyContainer.sharedInstance().dateProvider = date
            system.overrides.cpuUsage = 10
            system.overrides.memoryFootprintBytes = 100
            system.overrides.cpuEnergyUsage = 100
            SentryMetricProfiler.setSystemWrapperOverride(system)
        }
    }

    private var fixture: Fixture!

    override func setUp() {
        super.setUp()
        fixture = Fixture()
    }

    override func tearDown() {
        // These tests replace process-wide SDK and profiling dependencies.
        // swiftlint:disable:next avoid_clear_test_state
        clearTestState()
        SentryMetricProfiler.setSystemWrapperOverride(nil)
        super.tearDown()
    }

    /**
     Given a cumulative energy counter that decreases,
     when the profiler records the lower value and a subsequent increase,
     then it skips the invalid delta and measures from the new baseline.
     */
    func testRecordEnergy_whenCounterDecreases_shouldSkipInvalidDeltaAndRebase() throws {
        // -- Arrange --
        let profiler = SentryMetricProfiler(mode: .continuous)
        profiler.recordMetrics()
        fixture.date.advance(by: 1)
        fixture.system.overrides.cpuEnergyUsage = 80

        // -- Act --
        profiler.recordMetrics()
        fixture.date.advance(by: 1)
        fixture.system.overrides.cpuEnergyUsage = 90
        profiler.recordMetrics()

        // -- Assert --
        try assertEnergy(profiler, values: [10], timestamps: [1_002])
    }

    /**
     Given an established energy baseline and a failed counter read,
     when the next read succeeds,
     then the delta uses the last successful counter rather than the failed read.
     */
    func testRecordEnergy_whenReadFails_shouldUseLastSuccessfulBaseline() throws {
        // -- Arrange --
        let profiler = SentryMetricProfiler(mode: .continuous)
        profiler.recordMetrics()
        fixture.date.advance(by: 1)
        fixture.system.overrides.cpuEnergyUsage = 110
        fixture.system.overrides.cpuEnergyUsageError = NSError(domain: "metric-test", code: 1)

        // -- Act --
        profiler.recordMetrics()
        fixture.system.overrides.cpuEnergyUsageError = nil
        fixture.system.overrides.cpuEnergyUsage = 130
        fixture.date.advance(by: 1)
        profiler.recordMetrics()

        // -- Assert --
        try assertEnergy(profiler, values: [30], timestamps: [1_002])
    }

    /**
     Given a profiler with a successful energy reading,
     when buffered readings are cleared before the next batch,
     then the cumulative counter baseline survives the clear.
     */
    func testClear_whenNextChunkRecordsEnergy_shouldPreservePreviousCounterBaseline() throws {
        // -- Arrange --
        let profiler = SentryMetricProfiler(mode: .continuous)
        profiler.recordMetrics()
        fixture.date.advance(by: 1)
        fixture.system.overrides.cpuEnergyUsage = 110
        profiler.recordMetrics()
        try assertEnergy(profiler, values: [10], timestamps: [1_001])

        // -- Act --
        profiler.clear()
        fixture.date.advance(by: 1)
        fixture.system.overrides.cpuEnergyUsage = 130
        profiler.recordMetrics()

        // -- Assert --
        try assertEnergy(profiler, values: [20], timestamps: [1_002])
    }

    /**
     Given concurrent recordings of the same cumulative energy counter,
     when they establish and update the shared baseline,
     then exactly one recording establishes the baseline and all others emit zero deltas.
     */
    func testRecordEnergy_whenRecordingConcurrently_shouldEstablishBaselineExactlyOnce() throws {
        // -- Arrange --
        let profiler = SentryMetricProfiler(mode: .continuous)

        // -- Act --
        DispatchQueue.concurrentPerform(iterations: 200) { _ in
            profiler.recordMetrics()
        }

        // -- Assert --
        try assertEnergy(profiler, values: Array(repeating: 0, count: 199),
                         timestamps: Array(repeating: 1_000, count: 199))
    }

    private func assertEnergy(_ profiler: SentryMetricProfiler, values: [Double], timestamps: [TimeInterval], file: StaticString = #filePath, line: UInt = #line) throws {
        let metrics = serializeContinuousProfileMetrics(profiler.copyData())
        let metric = try XCTUnwrap(metrics["cpu_energy_usage"] as? [String: Any], file: file, line: line)
        XCTAssertEqual(metric["unit"] as? String, "nanojoule", file: file, line: line)
        let readings = try XCTUnwrap(metric["values"] as? [[String: Any]], file: file, line: line)
        XCTAssertEqual(readings.count, values.count, file: file, line: line)
        XCTAssertEqual(readings.compactMap { $0["value"] as? Double }, values, file: file, line: line)
        XCTAssertEqual(readings.compactMap { $0["timestamp"] as? TimeInterval }, timestamps, file: file, line: line)
    }
}
#endif
