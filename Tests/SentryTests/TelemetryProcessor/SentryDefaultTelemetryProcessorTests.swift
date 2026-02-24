@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

final class SentryDefaultTelemetryProcessorTests: XCTestCase {

    // MARK: - Add Log Tests

    func testAdd_whenCalledWithLog_shouldForwardToLogBuffer() throws {
        // -- Arrange --
        let (logBuffer, logScheduler) = createLogBuffer()
        let (metricsBuffer, _) = createMetricsBuffer()
        let sut = SentryDefaultTelemetryProcessor(logBuffer: logBuffer, metricsBuffer: metricsBuffer)
        let log = createTestLog(body: "Test message")

        // -- Act --
        sut.add(log: log)
        _ = sut.forwardTelemetryData()

        // -- Assert --
        XCTAssertEqual(logScheduler.captureInvocations.count, 1)
        XCTAssertEqual(logScheduler.captureInvocations.first?.telemetryType, .log)
    }

    func testAdd_whenCalledMultipleTimes_shouldForwardAllLogs() throws {
        // -- Arrange --
        let (logBuffer, logScheduler) = createLogBuffer()
        let (metricsBuffer, _) = createMetricsBuffer()
        let sut = SentryDefaultTelemetryProcessor(logBuffer: logBuffer, metricsBuffer: metricsBuffer)
        let log1 = createTestLog(body: "Log 1")
        let log2 = createTestLog(body: "Log 2")
        let log3 = createTestLog(body: "Log 3")

        // -- Act --
        sut.add(log: log1)
        sut.add(log: log2)
        sut.add(log: log3)
        _ = sut.forwardTelemetryData()

        // -- Assert --
        XCTAssertEqual(logScheduler.captureInvocations.count, 1)

        let capturedLogs = try logScheduler.getCapturedLogs()
        XCTAssertEqual(capturedLogs.count, 3)
        XCTAssertEqual(capturedLogs[0].body, "Log 1")
        XCTAssertEqual(capturedLogs[1].body, "Log 2")
        XCTAssertEqual(capturedLogs[2].body, "Log 3")
    }

    // MARK: - Add Metric Tests

    func testAdd_whenCalledWithMetric_shouldForwardToMetricsBuffer() throws {
        // -- Arrange --
        let (logBuffer, _) = createLogBuffer()
        let (metricsBuffer, metricsScheduler) = createMetricsBuffer()
        let sut = SentryDefaultTelemetryProcessor(logBuffer: logBuffer, metricsBuffer: metricsBuffer)
        let metric = createTestMetric(name: "test.metric")

        // -- Act --
        sut.add(metric: metric)
        _ = sut.forwardTelemetryData()

        // -- Assert --
        XCTAssertEqual(metricsScheduler.captureInvocations.count, 1)
        XCTAssertEqual(metricsScheduler.captureInvocations.first?.telemetryType, .metric)
    }

    func testAdd_whenCalledMultipleTimesWithMetrics_shouldForwardAllMetrics() throws {
        // -- Arrange --
        let (logBuffer, _) = createLogBuffer()
        let (metricsBuffer, metricsScheduler) = createMetricsBuffer()
        let sut = SentryDefaultTelemetryProcessor(logBuffer: logBuffer, metricsBuffer: metricsBuffer)
        let metric1 = createTestMetric(name: "metric.1")
        let metric2 = createTestMetric(name: "metric.2")
        let metric3 = createTestMetric(name: "metric.3")

        // -- Act --
        sut.add(metric: metric1)
        sut.add(metric: metric2)
        sut.add(metric: metric3)
        _ = sut.forwardTelemetryData()

        // -- Assert --
        XCTAssertEqual(metricsScheduler.captureInvocations.count, 1)

        let capturedMetrics = try metricsScheduler.getCapturedMetrics()
        XCTAssertEqual(capturedMetrics.count, 3)
        XCTAssertEqual(capturedMetrics[0].name, "metric.1")
        XCTAssertEqual(capturedMetrics[1].name, "metric.2")
        XCTAssertEqual(capturedMetrics[2].name, "metric.3")
    }

    // MARK: - Flush Tests

    func testFlush_whenCalled_shouldReturnDurationFromBothBuffers() {
        // -- Arrange --
        let (logBuffer, _) = createLogBuffer()
        let (metricsBuffer, _) = createMetricsBuffer()
        let sut = SentryDefaultTelemetryProcessor(logBuffer: logBuffer, metricsBuffer: metricsBuffer)
        sut.add(log: createTestLog(body: "Test"))
        sut.add(metric: createTestMetric(name: "test.metric"))

        // -- Act --
        let duration = sut.forwardTelemetryData()

        // -- Assert --
        XCTAssertGreaterThanOrEqual(duration, 0.0)
    }

    // MARK: - Integration Tests

    func testConcurrentAdds_ThreadSafe() throws {
        // -- Arrange --
        let itemCount = 100
        let maxItemCount = 100
        let logScheduler = TestTelemetryScheduler()
        let metricsScheduler = TestTelemetryScheduler()
        let dateProvider = TestCurrentDateProvider()
        let logForwardingTriggers = MockTelemetryBufferDataForwardingTriggers()
        let metricsForwardingTriggers = MockTelemetryBufferDataForwardingTriggers()

        let logBuffer = DefaultTelemetryBuffer<InMemoryInternalTelemetryBuffer<SentryLog>, SentryLog>(
            config: .init(
                flushTimeout: 5,
                maxItemCount: maxItemCount,
                maxBufferSizeBytes: 1_024 * 1_024,
                capturedDataCallback: { data, count in
                    logScheduler.capture(data: data, count: count, telemetryType: .log)
                }
            ),
            buffer: InMemoryInternalTelemetryBuffer(),
            dateProvider: dateProvider,
            dispatchQueue: SentryDispatchQueueWrapper(),
            itemForwardingTriggers: logForwardingTriggers
        )
        let metricsBuffer = DefaultTelemetryBuffer<InMemoryInternalTelemetryBuffer<SentryMetric>, SentryMetric>(
            config: .init(
                flushTimeout: 5,
                maxItemCount: maxItemCount,
                maxBufferSizeBytes: 1_024 * 1_024,
                capturedDataCallback: { data, count in
                    metricsScheduler.capture(data: data, count: count, telemetryType: .metric)
                }
            ),
            buffer: InMemoryInternalTelemetryBuffer(),
            dateProvider: dateProvider,
            dispatchQueue: SentryDispatchQueueWrapper(),
            itemForwardingTriggers: metricsForwardingTriggers
        )
        let sut = SentryDefaultTelemetryProcessor(logBuffer: logBuffer, metricsBuffer: metricsBuffer)

        let expectation = XCTestExpectation(description: "Concurrent adds")
        expectation.expectedFulfillmentCount = itemCount * 2

        // -- Act --
        for i in 0..<itemCount {
            DispatchQueue.global().async {
                let log = self.createTestLog(body: "Log \(i)")
                sut.add(log: log)
                expectation.fulfill()
            }
            DispatchQueue.global().async {
                let metric = self.createTestMetric(name: "metric.\(i)")
                sut.add(metric: metric)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 5.0)
        _ = sut.forwardTelemetryData()

        // -- Assert --
        let capturedLogs = try logScheduler.getCapturedLogs()
        XCTAssertEqual(capturedLogs.count, itemCount, "All concurrently added logs should be captured")

        let capturedMetrics = try metricsScheduler.getCapturedMetrics()
        XCTAssertEqual(capturedMetrics.count, itemCount, "All concurrently added metrics should be captured")
    }

    func testDispatchAfterTimeoutWithRealDispatchQueue() throws {
        // -- Arrange --
        let scheduler = TestTelemetryScheduler()
        let dateProvider = TestCurrentDateProvider()
        let itemForwardingTriggers = MockTelemetryBufferDataForwardingTriggers()

        let logBuffer = DefaultTelemetryBuffer<InMemoryInternalTelemetryBuffer<SentryLog>, SentryLog>(
            config: .init(
                flushTimeout: 0.2,
                maxItemCount: 1_000,
                maxBufferSizeBytes: 10_000,
                capturedDataCallback: { data, count in
                    scheduler.capture(data: data, count: count, telemetryType: .log)
                }
            ),
            buffer: InMemoryInternalTelemetryBuffer(),
            dateProvider: dateProvider,
            dispatchQueue: SentryDispatchQueueWrapper(),
            itemForwardingTriggers: itemForwardingTriggers
        )
        let (metricsBuffer, _) = createMetricsBuffer()
        let sut = SentryDefaultTelemetryProcessor(logBuffer: logBuffer, metricsBuffer: metricsBuffer)

        let log = createTestLog(body: "Real timeout test log")
        let expectation = XCTestExpectation(description: "Real timeout flush")

        // -- Act --
        sut.add(log: log)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // -- Assert --
        XCTAssertEqual(scheduler.captureInvocations.count, 1, "Timeout should trigger flush")
        XCTAssertEqual(scheduler.captureInvocations.first?.telemetryType, .log)

        let capturedLogs = try scheduler.getCapturedLogs()
        XCTAssertEqual(capturedLogs.count, 1, "Should contain exactly one log")
        XCTAssertEqual(capturedLogs[0].body, "Real timeout test log")
    }

    // MARK: - Helper Methods

    private func createLogBuffer() -> (buffer: any TelemetryBuffer<SentryLog>, scheduler: TestTelemetryScheduler) {
        let scheduler = TestTelemetryScheduler()
        let dateProvider = TestCurrentDateProvider()
        let dispatchQueue = TestSentryDispatchQueueWrapper()
        dispatchQueue.dispatchAsyncExecutesBlock = true
        let itemForwardingTriggers = MockTelemetryBufferDataForwardingTriggers()

        let logBuffer = DefaultTelemetryBuffer<InMemoryInternalTelemetryBuffer<SentryLog>, SentryLog>(
            config: .init(
                flushTimeout: 5.0,
                maxItemCount: 100,
                maxBufferSizeBytes: 1_024,
                capturedDataCallback: { data, count in
                    scheduler.capture(data: data, count: count, telemetryType: .log)
                }
            ),
            buffer: InMemoryInternalTelemetryBuffer(),
            dateProvider: dateProvider,
            dispatchQueue: dispatchQueue,
            itemForwardingTriggers: itemForwardingTriggers
        )

        return (logBuffer, scheduler)
    }

    private func createMetricsBuffer() -> (buffer: any TelemetryBuffer<SentryMetric>, scheduler: TestTelemetryScheduler) {
        let scheduler = TestTelemetryScheduler()
        let dateProvider = TestCurrentDateProvider()
        let dispatchQueue = TestSentryDispatchQueueWrapper()
        dispatchQueue.dispatchAsyncExecutesBlock = true
        let itemForwardingTriggers = MockTelemetryBufferDataForwardingTriggers()

        let metricsBuffer = DefaultTelemetryBuffer<InMemoryInternalTelemetryBuffer<SentryMetric>, SentryMetric>(
            config: .init(
                flushTimeout: 5.0,
                maxItemCount: 100,
                maxBufferSizeBytes: 1_024,
                capturedDataCallback: { data, count in
                    scheduler.capture(data: data, count: count, telemetryType: .metric)
                }
            ),
            buffer: InMemoryInternalTelemetryBuffer(),
            dateProvider: dateProvider,
            dispatchQueue: dispatchQueue,
            itemForwardingTriggers: itemForwardingTriggers
        )

        return (metricsBuffer, scheduler)
    }

    private func createTestLog(
        body: String,
        level: SentryLog.Level = .info
    ) -> SentryLog {
        return SentryLog(
            timestamp: Date(timeIntervalSince1970: 1_627_846_801),
            traceId: SentryId.empty,
            level: level,
            body: body,
            attributes: [:]
        )
    }

    private func createTestMetric(
        name: String,
        value: SentryMetric.Value = .counter(1)
    ) -> SentryMetric {
        return SentryMetric(
            timestamp: Date(timeIntervalSince1970: 1_627_846_801),
            traceId: SentryId.empty,
            name: name,
            value: value,
            unit: nil,
            attributes: [:]
        )
    }

}

// MARK: - Test Helpers

final class TestTelemetryScheduler: TelemetryScheduler {
    let captureInvocations = Invocations<(data: Data, count: Int, telemetryType: TelemetrySchedulerItemType)>()

    func capture(data: Data, count: Int, telemetryType: TelemetrySchedulerItemType) {
        captureInvocations.record((data, count, telemetryType))
    }

    func getCapturedLogs() throws -> [SentryLog] {
        var allLogs: [SentryLog] = []

        for invocation in captureInvocations.invocations {
            let jsonObject = try XCTUnwrap(JSONSerialization.jsonObject(with: invocation.data) as? [String: Any])
            if let items = jsonObject["items"] as? [[String: Any]] {
                for item in items {
                    if let log = try parseSentryLog(from: item) {
                        allLogs.append(log)
                    }
                }
            }
        }

        return allLogs
    }

    func getCapturedMetrics() throws -> [SentryMetric] {
        var allMetrics: [SentryMetric] = []

        for invocation in captureInvocations.invocations {
            let jsonObject = try XCTUnwrap(JSONSerialization.jsonObject(with: invocation.data) as? [String: Any])
            if let items = jsonObject["items"] as? [[String: Any]] {
                for item in items {
                    if let metric = parseSentryMetric(from: item) {
                        allMetrics.append(metric)
                    }
                }
            }
        }

        return allMetrics
    }

    private func parseSentryLog(from dict: [String: Any]) throws -> SentryLog? {
        guard let body = dict["body"] as? String,
              let levelString = dict["level"] as? String else {
            return nil
        }
        let level = try SentryLog.Level(value: levelString)

        let timestamp = Date(timeIntervalSince1970: (dict["timestamp"] as? TimeInterval) ?? 0)
        let traceIdString = dict["trace_id"] as? String ?? ""
        let traceId = SentryId(uuidString: traceIdString)

        var attributes: [String: SentryLog.Attribute] = [:]
        if let attributesDict = dict["attributes"] as? [String: [String: Any]] {
            for (key, value) in attributesDict {
                if let attrValue = value["value"] {
                    attributes[key] = SentryLog.Attribute(value: attrValue)
                }
            }
        }

        return SentryLog(timestamp: timestamp, traceId: traceId, level: level, body: body, attributes: attributes)
    }

    private func parseSentryMetric(from dict: [String: Any]) -> SentryMetric? {
        guard let name = dict["name"] as? String,
              let typeString = dict["type"] as? String else {
            return nil
        }

        let value: SentryMetricValue
        switch typeString {
        case "counter":
            let intValue = dict["value"] as? Int ?? 0
            value = .counter(UInt(max(intValue, 0)))
        case "gauge":
            let doubleValue = dict["value"] as? Double ?? 0
            value = .gauge(doubleValue)
        case "distribution":
            let doubleValue = dict["value"] as? Double ?? 0
            value = .distribution(doubleValue)
        default:
            return nil
        }

        let timestamp = Date(timeIntervalSince1970: (dict["timestamp"] as? TimeInterval) ?? 0)
        let traceIdString = dict["trace_id"] as? String ?? ""
        let traceId = SentryId(uuidString: traceIdString)

        var attributes: [String: SentryMetric.Attribute] = [:]
        if let attributesDict = dict["attributes"] as? [String: [String: Any]] {
            for (key, attrDict) in attributesDict {
                if let attrValue = attrDict["value"] {
                    attributes[key] = SentryAttributeContent.from(anyValue: attrValue)
                }
            }
        }

        return SentryMetric(
            timestamp: timestamp,
            traceId: traceId,
            name: name,
            value: value,
            unit: nil,
            attributes: attributes
        )
    }
}

private class MockTelemetryBufferDataForwardingTriggers: TelemetryBufferItemForwardingTriggers {
    private weak var delegate: TelemetryBufferItemForwardingDelegate?

    func setDelegate(_ delegate: TelemetryBufferItemForwardingDelegate?) {
        self.delegate = delegate
    }

    func invokeDelegate() {
        delegate?.forwardItems()
    }
}
