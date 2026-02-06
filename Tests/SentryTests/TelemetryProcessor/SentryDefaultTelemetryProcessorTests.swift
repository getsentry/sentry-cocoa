@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

final class SentryDefaultTelemetryProcessorTests: XCTestCase {

    // MARK: - Add Log Tests

    func testAdd_whenCalledWithLog_shouldForwardToLogBuffer() throws {
        // -- Arrange --
        let (logBuffer, scheduler) = createLogBuffer()
        let sut = SentryDefaultTelemetryProcessor(logBuffer: logBuffer)
        let log = createTestLog(body: "Test message")

        // -- Act --
        sut.add(log: log)
        _ = sut.forwardTelemetryData()

        // -- Assert --
        XCTAssertEqual(scheduler.captureInvocations.count, 1)
        XCTAssertEqual(scheduler.captureInvocations.first?.telemetryType, .log)
    }

    func testAdd_whenCalledMultipleTimes_shouldForwardAllLogs() throws {
        // -- Arrange --
        let (logBuffer, scheduler) = createLogBuffer()
        let sut = SentryDefaultTelemetryProcessor(logBuffer: logBuffer)
        let log1 = createTestLog(body: "Log 1")
        let log2 = createTestLog(body: "Log 2")
        let log3 = createTestLog(body: "Log 3")

        // -- Act --
        sut.add(log: log1)
        sut.add(log: log2)
        sut.add(log: log3)
        _ = sut.forwardTelemetryData()

        // -- Assert --
        XCTAssertEqual(scheduler.captureInvocations.count, 1)

        let capturedData = try XCTUnwrap(scheduler.captureInvocations.first?.data)
        let capturedLogs = parseLogsFromData(capturedData)

        XCTAssertEqual(capturedLogs.count, 3)
        XCTAssertEqual(capturedLogs[0].body, "Log 1")
        XCTAssertEqual(capturedLogs[1].body, "Log 2")
        XCTAssertEqual(capturedLogs[2].body, "Log 3")
    }

    // MARK: - Flush Tests

    func testFlush_whenCalled_shouldReturnDurationFromLogBuffer() {
        // -- Arrange --
        let (logBuffer, _) = createLogBuffer()
        let sut = SentryDefaultTelemetryProcessor(logBuffer: logBuffer)
        let log = createTestLog(body: "Test")
        sut.add(log: log)

        // -- Act --
        let duration = sut.forwardTelemetryData()

        // -- Assert --
        XCTAssertGreaterThanOrEqual(duration, 0.0)
    }

    // MARK: - Integration Tests

    func testConcurrentAdds_ThreadSafe() throws {
        // -- Arrange --
        let scheduler = TestTelemetryScheduler()
        let dateProvider = TestCurrentDateProvider()
        let itemForwardingTriggers = MockTelemetryBufferDataForwardingTriggers()

        let logBuffer = DefaultTelemetryBuffer<InMemoryInternalTelemetryBuffer<SentryLog>, SentryLog>(
            config: .init(
                flushTimeout: 5,
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
        let sut = SentryDefaultTelemetryProcessor(logBuffer: logBuffer)

        let expectation = XCTestExpectation(description: "Concurrent adds")
        expectation.expectedFulfillmentCount = 10

        // -- Act --
        for i in 0..<10 {
            DispatchQueue.global().async {
                let log = self.createTestLog(body: "Log \(i)")
                sut.add(log: log)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 1.0)
        _ = sut.forwardTelemetryData()

        // -- Assert --
        let capturedLogs = scheduler.getCapturedLogs()
        XCTAssertEqual(capturedLogs.count, 10, "All 10 concurrently added logs should be in the batch")
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
        let sut = SentryDefaultTelemetryProcessor(logBuffer: logBuffer)

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

        let capturedLogs = scheduler.getCapturedLogs()
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

    private func parseLogsFromData(_ data: Data) -> [SentryLog] {
        var logs: [SentryLog] = []

        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = jsonObject["items"] as? [[String: Any]] else {
            return logs
        }

        for item in items {
            if let log = parseSentryLog(from: item) {
                logs.append(log)
            }
        }

        return logs
    }

    private func parseSentryLog(from dict: [String: Any]) -> SentryLog? {
        guard let body = dict["body"] as? String,
              let levelString = dict["level"] as? String,
              let level = try? SentryLog.Level(value: levelString) else {
            return nil
        }

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
}

// MARK: - Test Helpers

final class TestTelemetryScheduler: TelemetryScheduler {
    let captureInvocations = Invocations<(data: Data, count: Int, telemetryType: TelemetrySchedulerItemType)>()

    func capture(data: Data, count: Int, telemetryType: TelemetrySchedulerItemType) {
        captureInvocations.record((data, count, telemetryType))
    }

    func getCapturedLogs() -> [SentryLog] {
        var allLogs: [SentryLog] = []

        for invocation in captureInvocations.invocations {
            if let jsonObject = try? JSONSerialization.jsonObject(with: invocation.data) as? [String: Any],
               let items = jsonObject["items"] as? [[String: Any]] {
                for item in items {
                    if let log = parseSentryLog(from: item) {
                        allLogs.append(log)
                    }
                }
            }
        }

        return allLogs
    }

    private func parseSentryLog(from dict: [String: Any]) -> SentryLog? {
        guard let body = dict["body"] as? String,
              let levelString = dict["level"] as? String,
              let level = try? SentryLog.Level(value: levelString) else {
            return nil
        }

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
