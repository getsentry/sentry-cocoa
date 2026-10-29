#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
@_spi(Private) @testable import SentryTestUtils
import _SentryPrivate
import XCTest

#if os(iOS) || os(macOS)
final class SentryMetricProfilerTests: XCTestCase {
    private struct Fixture {
        let date = TestCurrentDateProvider()
        let system = TestSentrySystemWrapper()
        let dispatchFactory = TestDispatchFactory()
        let queue = TestSentryDispatchQueueWrapper()
        let client: TestClient
        let hub: SentryHubInternal

        init() throws {
            date.setDate(date: Date(timeIntervalSince1970: 1_000))
            let container = SentryDependencyContainer.sharedInstance()
            container.dateProvider = date
            container.dispatchQueueWrapper = queue
            container.dispatchFactory = dispatchFactory
            container.timerFactory = TestSentryNSTimerFactory(currentDateProvider: date)
            container.notificationCenterWrapper = TestNSNotificationCenterWrapper()
            system.overrides.cpuUsage = 10
            system.overrides.memoryFootprintBytes = 100
            system.overrides.cpuEnergyUsage = 100
            SentryMetricProfiler.setSystemWrapperOverride(system)
            let options = Options()
            options.dsn = TestConstants.dsnForTestCase(type: SentryMetricProfilerTests.self)
            client = try XCTUnwrap(TestClient(options: options))
            hub = SentryHubInternal(client: client, andScope: Scope())
            SentrySDKInternal.setCurrentHub(hub)
        }
    }

    private var fixture: Fixture!

    override func setUpWithError() throws {
        try super.setUpWithError()
        fixture = try Fixture()
    }

    override func tearDown() {
        // These tests replace process-wide SDK and profiling dependencies.
        // swiftlint:disable:next avoid_clear_test_state
        clearTestState()
        SentryMetricProfiler.setSystemWrapperOverride(nil)
        super.tearDown()
    }

    func testRecordMetrics_whenValuesChange_shouldSerializeEveryValueWithEpochSeconds() throws {
        // -- Arrange --
        let profiler = SentryMetricProfiler(mode: .continuous)
        fixture.date.advance(by: 0.125)
        fixture.system.overrides.cpuUsage = 12.5
        profiler.recordMetrics()
        fixture.date.advance(by: 1.25)
        fixture.system.overrides.cpuUsage = 23.25
        fixture.system.overrides.memoryFootprintBytes = 200
        fixture.system.overrides.cpuEnergyUsage = 110
        profiler.recordMetrics()
        fixture.date.advance(by: 0.5)
        fixture.system.overrides.cpuUsage = 0
        fixture.system.overrides.memoryFootprintBytes = 300
        fixture.system.overrides.cpuEnergyUsage = 130

        // -- Act --
        profiler.recordMetrics()
        let metrics = serializeContinuousProfileMetrics(profiler.copyData())

        // -- Assert --
        try assertMetric(metrics, key: "cpu_usage", unit: "percent", values: [12.5, 23.25, 0], timestamps: [1_000.125, 1_001.375, 1_001.875])
        try assertMetric(metrics, key: "memory_footprint", unit: "byte", values: [100, 200, 300], timestamps: [1_000.125, 1_001.375, 1_001.875])
#if arch(arm) || arch(arm64)
        try assertMetric(metrics, key: "cpu_energy_usage", unit: "nanojoule", values: [10, 20], timestamps: [1_001.375, 1_001.875])
#else
        XCTAssertNil(metrics["cpu_energy_usage"])
#endif
    }

    func testSerializeTraceMetrics_whenReadingsStraddleBoundaries_shouldIncludeBoundsAndNormalizeTime() throws {
        // -- Arrange --
        let profiler = SentryMetricProfiler(mode: .trace)
        for value in 0...4 {
            fixture.system.overrides.cpuUsage = NSNumber(value: Double(value) / 4)
            fixture.system.overrides.memoryFootprintBytes = NSNumber(value: value * 100)
            fixture.system.overrides.cpuEnergyUsage = NSNumber(value: value * value)
            profiler.recordMetrics()
            fixture.date.advanceBy(nanoseconds: 1)
        }

        // -- Act --
        let metrics = profiler.serializeTraceProfileMetricsBetween(1, and: 3)
        let outside = profiler.serializeTraceProfileMetricsBetween(10, and: 20)

        // -- Assert --
        for (key, unit, expected) in [("cpu_usage", "percent", [0.25, 0.5, 0.75]), ("memory_footprint", "byte", [100.0, 200.0, 300.0])] {
            let metric = try XCTUnwrap(metrics[key] as? [String: Any])
            XCTAssertEqual(metric["unit"] as? String, unit)
            let values = try XCTUnwrap(metric["values"] as? [[String: Any]])
            XCTAssertEqual(values.compactMap { $0["value"] as? Double }, expected)
            XCTAssertEqual(values.compactMap { $0["elapsed_since_start_ns"] as? String }, ["0", "1", "2"])
        }
#if arch(arm) || arch(arm64)
        let energy = try XCTUnwrap(metrics["cpu_energy_usage"] as? [String: Any])
        XCTAssertEqual(energy["unit"] as? String, "nanojoule")
        let energyValues = try XCTUnwrap(energy["values"] as? [[String: Any]])
        XCTAssertEqual(energyValues.compactMap { $0["value"] as? Int }, [1, 3, 5])
        XCTAssertEqual(energyValues.compactMap { $0["elapsed_since_start_ns"] as? String }, ["0", "1", "2"])
#endif
        XCTAssertEqual(outside.count, 0)
    }

    func testRecordMetrics_whenOneReadFails_shouldPreserveOtherMetricsAndRecover() throws {
        var failingMetrics = ["cpu_usage", "memory_footprint"]
#if arch(arm) || arch(arm64)
        failingMetrics.append("cpu_energy_usage")
#endif
        for failingMetric in failingMetrics {
            // -- Arrange --
            let profiler = SentryMetricProfiler(mode: .continuous)
            profiler.recordMetrics()
            profiler.clear()
            let error = NSError(domain: "metric-test", code: 1)
            fixture.system.overrides.cpuUsageError = failingMetric == "cpu_usage" ? error : nil
            fixture.system.overrides.memoryFootprintError = failingMetric == "memory_footprint" ? error : nil
            fixture.system.overrides.cpuEnergyUsageError = failingMetric == "cpu_energy_usage" ? error : nil
            fixture.system.overrides.cpuUsage = 20
            fixture.system.overrides.memoryFootprintBytes = 200
            fixture.system.overrides.cpuEnergyUsage = 110
            let start = fixture.date.date().timeIntervalSince1970
            fixture.date.advance(by: 1)

            // -- Act --
            profiler.recordMetrics()
            fixture.system.overrides.cpuUsageError = nil
            fixture.system.overrides.memoryFootprintError = nil
            fixture.system.overrides.cpuEnergyUsageError = nil
            fixture.system.overrides.cpuUsage = 30
            fixture.system.overrides.memoryFootprintBytes = 300
            fixture.system.overrides.cpuEnergyUsage = 130
            fixture.date.advance(by: 1)
            profiler.recordMetrics()
            let metrics = serializeContinuousProfileMetrics(profiler.copyData())

            // -- Assert --
            try assertMetric(metrics, key: "cpu_usage", unit: "percent",
                             values: failingMetric == "cpu_usage" ? [30] : [20, 30],
                             timestamps: failingMetric == "cpu_usage" ? [start + 2] : [start + 1, start + 2])
            try assertMetric(metrics, key: "memory_footprint", unit: "byte",
                             values: failingMetric == "memory_footprint" ? [300] : [200, 300],
                             timestamps: failingMetric == "memory_footprint" ? [start + 2] : [start + 1, start + 2])
#if arch(arm) || arch(arm64)
            try assertMetric(metrics, key: "cpu_energy_usage", unit: "nanojoule",
                             values: failingMetric == "cpu_energy_usage" ? [30] : [10, 20],
                             timestamps: failingMetric == "cpu_energy_usage" ? [start + 2] : [start + 1, start + 2])
#endif
            fixture.system.overrides.cpuEnergyUsage = 100
        }
    }

#if arch(arm) || arch(arm64)
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
        let metrics = serializeContinuousProfileMetrics(profiler.copyData())

        // -- Assert --
        try assertMetric(metrics, key: "cpu_energy_usage", unit: "nanojoule", values: [10], timestamps: [1_002])
    }

    func testClear_whenNextChunkRecordsEnergy_shouldPreservePreviousCounterBaseline() throws {
        // -- Arrange --
        let profiler = SentryMetricProfiler(mode: .continuous)
        profiler.recordMetrics()
        fixture.date.advance(by: 1)
        fixture.system.overrides.cpuEnergyUsage = 110
        profiler.recordMetrics()
        let first = serializeContinuousProfileMetrics(profiler.copyData())

        // -- Act --
        profiler.clear()
        fixture.date.advance(by: 1)
        fixture.system.overrides.cpuEnergyUsage = 130
        profiler.recordMetrics()
        let second = serializeContinuousProfileMetrics(profiler.copyData())

        // -- Assert --
        try assertMetric(first, key: "cpu_energy_usage", unit: "nanojoule", values: [10], timestamps: [1_001])
        try assertMetric(second, key: "cpu_energy_usage", unit: "nanojoule", values: [20], timestamps: [1_002])
    }
#endif

    func testTransmitChunk_whenMetricsArriveAfterSnapshot_shouldKeepThemForNextChunk() throws {
        if sentry_threadSanitizerIsPresent() {
            throw XCTSkip("Native profiling is disabled when Thread Sanitizer is attached.")
        }
        // -- Arrange --
        SentryContinuousProfiler.start()
        defer { SentryContinuousProfiler.stopTimerAndCleanup() }
        let profiler = try XCTUnwrap(SentryContinuousProfiler.profiler())
        profiler.metricProfiler.stop()
        let metrics = MetricsAfterSnapshotProfiler(mode: .continuous)
        profiler.metricProfiler = metrics
        metrics.recordMetrics()
        let fixture = try XCTUnwrap(self.fixture)
        metrics.afterSnapshot = { [fixture, weak metrics] in
            fixture.date.advance(by: 1)
            fixture.system.overrides.cpuUsage = 20
            fixture.system.overrides.memoryFootprintBytes = 200
            fixture.system.overrides.cpuEnergyUsage = 110
            metrics?.recordMetrics()
        }

        // -- Act --
        SentryContinuousProfiler.transmitChunkEnvelope()
        SentryContinuousProfiler.transmitChunkEnvelope()

        // -- Assert --
        let chunks = try fixture.client.captureEnvelopeInvocations.invocations.map { envelope in
            let item = try XCTUnwrap(envelope.items.first)
            let payload = try XCTUnwrap(try JSONSerialization.jsonObject(with: XCTUnwrap(item.data)) as? [String: Any])
            return try XCTUnwrap(payload["measurements"] as? [String: Any])
        }
        XCTAssertEqual(chunks.count, 2)
        try assertMetric(XCTUnwrap(chunks.element(at: 0)), key: "cpu_usage", unit: "percent", values: [10], timestamps: [1_000])
        try assertMetric(XCTUnwrap(chunks.element(at: 1)), key: "cpu_usage", unit: "percent", values: [20], timestamps: [1_001])
        try assertMetric(XCTUnwrap(chunks.element(at: 1)), key: "memory_footprint", unit: "byte", values: [200], timestamps: [1_001])
#if arch(arm) || arch(arm64)
        try assertMetric(XCTUnwrap(chunks.element(at: 1)), key: "cpu_energy_usage", unit: "nanojoule", values: [10], timestamps: [1_001])
#endif
    }

    func testCopyAndClear_whenRecordingConcurrently_shouldPreserveEveryReadingExactlyOnce() throws {
        // -- Arrange --
        let profiler = SentryMetricProfiler(mode: .continuous)
        var snapshots: [[AnyHashable: Any]] = []

        // -- Act --
        DispatchQueue.concurrentPerform(iterations: 3) { worker in
            for _ in 0..<100 {
                if worker < 2 {
                    profiler.recordMetrics()
                } else {
                    snapshots.append(profiler.copyAndClearData())
                }
            }
        }
        snapshots.append(profiler.copyAndClearData())
        let serialized = snapshots.map { serializeContinuousProfileMetrics($0) }

        // -- Assert --
        for (key, expectedValue) in [("cpu_usage", 10), ("memory_footprint", 100)] {
            let readings = serialized.flatMap { metrics in
                (metrics[key] as? [String: Any])?["values"] as? [[String: Any]] ?? []
            }
            XCTAssertEqual(readings.count, 200)
            XCTAssertEqual(readings.compactMap { $0["value"] as? Int }, Array(repeating: expectedValue, count: 200))
            XCTAssertEqual(readings.compactMap { $0["timestamp"] as? TimeInterval }, Array(repeating: 1_000, count: 200))
        }
#if arch(arm) || arch(arm64)
        let energy = serialized.flatMap { metrics in
            (metrics["cpu_energy_usage"] as? [String: Any])?["values"] as? [[String: Any]] ?? []
        }
        XCTAssertEqual(energy.count, 199)
        XCTAssertEqual(energy.compactMap { $0["value"] as? Int }, Array(repeating: 0, count: 199))
        XCTAssertEqual(energy.compactMap { $0["timestamp"] as? TimeInterval }, Array(repeating: 1_000, count: 199))
#endif
    }

    func testCopyAndClear_whenChunkContainsOneMinuteOfMetrics_shouldMeasureWallClockTime() throws {
        // -- Arrange --
        let options = XCTMeasureOptions.default
        options.invocationOptions = [.manuallyStart, .manuallyStop]

        measure(metrics: [XCTClockMetric()], options: options) { [self] in
            let profiler = SentryMetricProfiler(mode: .continuous)
            // Release setup temporaries before measuring the snapshot/reset operation.
            autoreleasepool {
                for _ in 0..<600 {
                    profiler.recordMetrics()
                    fixture.date.advance(by: 0.1)
                }
            }

            // -- Act --
            startMeasuring()
            let snapshot = profiler.copyAndClearData()
            stopMeasuring()

            // -- Assert --
            let metrics = serializeContinuousProfileMetrics(snapshot)
            for key in ["cpu_usage", "memory_footprint"] {
                let metric = metrics[key] as? [String: Any]
                XCTAssertEqual((metric?["values"] as? [Any])?.count, 600)
            }
#if arch(arm) || arch(arm64)
            let energy = metrics["cpu_energy_usage"] as? [String: Any]
            XCTAssertEqual((energy?["values"] as? [Any])?.count, 599)
#endif
            XCTAssertTrue(serializeContinuousProfileMetrics(profiler.copyData()).isEmpty)
        }
    }

    private func assertMetric(_ metrics: [String: Any], key: String, unit: String, values: [Double], timestamps: [TimeInterval], file: StaticString = #filePath, line: UInt = #line) throws {
        let metric = try XCTUnwrap(metrics[key] as? [String: Any], file: file, line: line)
        XCTAssertEqual(metric["unit"] as? String, unit, file: file, line: line)
        let readings = try XCTUnwrap(metric["values"] as? [[String: Any]], file: file, line: line)
        XCTAssertEqual(readings.count, values.count, file: file, line: line)
        XCTAssertEqual(readings.compactMap { $0["value"] as? Double }, values, file: file, line: line)
        XCTAssertEqual(readings.compactMap { $0["timestamp"] as? TimeInterval }, timestamps, file: file, line: line)
    }
}

// Inject a real metric recording after the snapshot lock is released.
private final class MetricsAfterSnapshotProfiler: SentryMetricProfiler {
    var afterSnapshot: (() -> Void)?

    override func copyData() -> [AnyHashable: Any] {
        let snapshot = super.copyData()
        recordPendingMetrics()
        return snapshot
    }

    override func copyAndClearData() -> [AnyHashable: Any] {
        let snapshot = super.copyAndClearData()
        recordPendingMetrics()
        return snapshot
    }

    private func recordPendingMetrics() {
        let callback = afterSnapshot
        afterSnapshot = nil
        callback?()
    }
}
#endif // os(iOS) || os(macOS)
