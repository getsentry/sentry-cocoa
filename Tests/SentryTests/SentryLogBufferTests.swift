@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

final class SentryLogBufferTests: XCTestCase {

    private var options: Options!
    private var testDateProvider: TestCurrentDateProvider!
    private var testScheduler: TestLogTelemetryScheduler!
    private var testDispatchQueue: TestSentryDispatchQueueWrapper!
    private var testNotificationCenter: TestNSNotificationCenterWrapper!
    private var testItemForwarding: MockTelemetryBufferDataForwardingTriggers!

    private func getSut() -> SentryLogBuffer {
        return SentryLogBuffer(
            flushTimeout: 0.1, // Very small timeout for testing
            maxLogCount: 10, // Maximum 10 logs per batch
            maxBufferSizeBytes: 8_000, // byte limit for testing (log with attributes ~390 bytes)
            dateProvider: testDateProvider,
            dispatchQueue: testDispatchQueue,
            scheduler: testScheduler,
            itemForwarding: testItemForwarding
        )
    }

    override func setUp() {
        super.setUp()

        options = Options()
        options.dsn = TestConstants.dsnForTestCase(type: Self.self)

        testDateProvider = TestCurrentDateProvider()
        testScheduler = TestLogTelemetryScheduler()
        testDispatchQueue = TestSentryDispatchQueueWrapper()
        testNotificationCenter = TestNSNotificationCenterWrapper()
        testItemForwarding = MockTelemetryBufferDataForwardingTriggers()
        testDispatchQueue.dispatchAsyncExecutesBlock = true // Execute encoding immediately
    }

    override func tearDown() {
        super.tearDown()
        testScheduler = nil
        testDispatchQueue = nil
    }
    
    // MARK: - Basic Functionality Tests
    
    func testAddMultipleLogs_BatchesTogether() throws {
        // -- Arrange --
        let sut = getSut()
        let log1 = createTestLog(body: "Log 1")
        let log2 = createTestLog(body: "Log 2")
        
        // -- Act --
        sut.addLog(log1)
        sut.addLog(log2)
        sut.captureLogs()
        
        // -- Assert --
        XCTAssertEqual(testScheduler.captureLogsDataInvocations.count, 1)
        XCTAssertEqual(testScheduler.captureLogsDataInvocations.invocations.first?.telemetryType, .log)

        let capturedLogs = testScheduler.getCapturedLogs()
        XCTAssertEqual(capturedLogs.count, 2)
        XCTAssertEqual(capturedLogs[0].body, "Log 1")
        XCTAssertEqual(capturedLogs[1].body, "Log 2")
    }
    
    // MARK: - Buffer Size Tests
    
    func testBufferReachesMaxSize_FlushesImmediately() throws {
        // -- Arrange --
        let sut = getSut()
        let largeLogBody = String(repeating: "A", count: 8_000) // Larger than 8000 byte limit
        let largeLog = createTestLog(body: largeLogBody)
        
        // -- Act --
        sut.addLog(largeLog)
        
        // -- Assert --
        XCTAssertEqual(testScheduler.captureLogsDataInvocations.count, 1)
        XCTAssertEqual(testScheduler.captureLogsDataInvocations.invocations.first?.telemetryType, .log)

        let capturedLogs = testScheduler.getCapturedLogs()
        XCTAssertEqual(capturedLogs.count, 1)
        XCTAssertEqual(capturedLogs[0].body, largeLogBody)
    }
    
    // MARK: - Max Log Count Tests
    
    func testMaxLogCount_FlushesWhenReached() throws {
        // -- Arrange --
        let sut = getSut()
        
        // -- Act --
        for i in 0..<9 {
            let log = createTestLog(body: "Log \(i + 1)")
            sut.addLog(log)
        }
        
        XCTAssertEqual(testScheduler.captureLogsDataInvocations.count, 0)
        
        let log = createTestLog(body: "Log \(10)") // Reached 10 max logs limit
        sut.addLog(log)
        
        // -- Assert --
        XCTAssertEqual(testScheduler.captureLogsDataInvocations.count, 1)
        XCTAssertEqual(testScheduler.captureLogsDataInvocations.invocations.first?.telemetryType, .log)

        let capturedLogs = testScheduler.getCapturedLogs()
        XCTAssertEqual(capturedLogs.count, 10, "Should have captured exactly \(10) logs")
    }
    
    // MARK: - Timeout Tests
    
    func testTimeout_FlushesAfterDelay() throws {
        // -- Arrange --
        let sut = getSut()
        let log = createTestLog()
        
        // -- Act --
        sut.addLog(log)
        testDispatchQueue.invokeLastDispatchAfterWorkItem()
        
        // -- Assert --
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.count, 1)
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.first?.interval, 0.1)
        XCTAssertEqual(testScheduler.captureLogsDataInvocations.count, 1)
        XCTAssertEqual(testScheduler.captureLogsDataInvocations.invocations.first?.telemetryType, .log)

        let capturedLogs = testScheduler.getCapturedLogs()
        XCTAssertEqual(capturedLogs.count, 1)
    }
    
    func testAddingLogToEmptyBuffer_StartsTimer() throws {
        // -- Arrange --
        let sut = getSut()
        let log1 = createTestLog(body: "Log 1")
        let log2 = createTestLog(body: "Log 2")
        
        // -- Act --
        sut.addLog(log1)
        sut.addLog(log2)
        testDispatchQueue.invokeLastDispatchAfterWorkItem()
        
        // -- Assert --
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.count, 1)
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.first?.interval, 0.1)
        XCTAssertEqual(testScheduler.captureLogsDataInvocations.count, 1)
        XCTAssertEqual(testScheduler.captureLogsDataInvocations.invocations.first?.telemetryType, .log)

        let capturedLogs = testScheduler.getCapturedLogs()
        XCTAssertEqual(capturedLogs.count, 2)
    }
     
     // MARK: - Manual Capture Logs Tests
    
    func testManualCaptureLogs_CapturesImmediately() throws {
        // -- Arrange --
        let sut = getSut()
        let log1 = createTestLog(body: "Log 1")
        let log2 = createTestLog(body: "Log 2")
        
        // -- Act --
        sut.addLog(log1)
        sut.addLog(log2)
        sut.captureLogs()
        
        // -- Assert --
        XCTAssertEqual(testScheduler.captureLogsDataInvocations.count, 1)
        XCTAssertEqual(testScheduler.captureLogsDataInvocations.invocations.first?.telemetryType, .log)

        let capturedLogs = testScheduler.getCapturedLogs()
        XCTAssertEqual(capturedLogs.count, 2)
    }
    
    func testManualCaptureLogs_CancelsScheduledCapture() throws {
        // -- Arrange --
        let sut = getSut()
        let log = createTestLog()
        sut.addLog(log)
        let timerWorkItem = try XCTUnwrap(testDispatchQueue.dispatchAfterWorkItemInvocations.first?.workItem)
        
        // -- Act --
        sut.captureLogs()
        timerWorkItem.perform()
        
        // -- Assert --
        XCTAssertEqual(testScheduler.captureLogsDataInvocations.count, 1, "Manual flush should work and timer should be cancelled")
        XCTAssertEqual(testScheduler.captureLogsDataInvocations.invocations.first?.telemetryType, .log)
    }

    func testManualCaptureLogs_WithEmptyBuffer_DoesNothing() {
        // -- Arrange --
        let sut = getSut()
        
        // -- Act --
        sut.captureLogs()
        
        // -- Assert --
        XCTAssertEqual(testScheduler.captureLogsDataInvocations.count, 0)
    }
    
    // MARK: - Edge Cases Tests
    
    func testScheduledFlushAfterBufferAlreadyFlushed_DoesNothing() throws {
        // -- Arrange --
        let sut = getSut()
        let largeLogBody = String(repeating: "B", count: 4_000)
        let log1 = createTestLog(body: largeLogBody)
        let log2 = createTestLog(body: largeLogBody)
        
        // -- Act --
        sut.addLog(log1)
        let timerWorkItem = try XCTUnwrap(testDispatchQueue.dispatchAfterWorkItemInvocations.first?.workItem)
        sut.addLog(log2)
        timerWorkItem.perform()
        
        // -- Assert --
        XCTAssertEqual(testScheduler.captureLogsDataInvocations.count, 1)
        XCTAssertEqual(testScheduler.captureLogsDataInvocations.invocations.first?.telemetryType, .log)
    }

    func testAddLogAfterFlush_StartsNewBatch() throws {
        // -- Arrange --
        let sut = getSut()
        let log1 = createTestLog(body: "Log 1")
        let log2 = createTestLog(body: "Log 2")
        
        // -- Act --
        sut.addLog(log1)
        sut.captureLogs()
        sut.addLog(log2)
        sut.captureLogs()
        
        // -- Assert --
        XCTAssertEqual(testScheduler.captureLogsDataInvocations.count, 2)
        XCTAssertEqual(testScheduler.captureLogsDataInvocations.invocations[0].telemetryType, .log)
        XCTAssertEqual(testScheduler.captureLogsDataInvocations.invocations[1].telemetryType, .log)

        let allCapturedLogs = testScheduler.getCapturedLogs()
        XCTAssertEqual(allCapturedLogs.count, 2)
        XCTAssertEqual(allCapturedLogs[0].body, "Log 1")
        XCTAssertEqual(allCapturedLogs[1].body, "Log 2")
    }
    
    // MARK: - Integration Tests
    
    func testConcurrentAdds_ThreadSafe() throws {
        // -- Arrange --
        let sutWithRealQueue = SentryLogBuffer(
            flushTimeout: 5,
            maxLogCount: 1_000, // Maximum 1000 logs per batch
            maxBufferSizeBytes: 10_000,
            dateProvider: testDateProvider,
            dispatchQueue: SentryDispatchQueueWrapper(),
            scheduler: testScheduler,
            itemForwarding: testItemForwarding
        )
        
        let expectation = XCTestExpectation(description: "Concurrent adds")
        expectation.expectedFulfillmentCount = 10
        
        // -- Act --
        for i in 0..<10 {
            DispatchQueue.global().async {
                let log = self.createTestLog(body: "Log \(i)")
                sutWithRealQueue.addLog(log)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 1.0)
        sutWithRealQueue.captureLogs()
        
        // -- Assert --
        let capturedLogs = self.testScheduler.getCapturedLogs()
        XCTAssertEqual(capturedLogs.count, 10, "All 10 concurrently added logs should be in the batch")
    }

    func testDispatchAfterTimeoutWithRealDispatchQueue() throws {
        // -- Arrange --
        let sutWithRealQueue = SentryLogBuffer(
            flushTimeout: 0.2,
            maxLogCount: 1_000, // Maximum 1000 logs per batch
            maxBufferSizeBytes: 10_000,
            dateProvider: testDateProvider,
            dispatchQueue: SentryDispatchQueueWrapper(),
            scheduler: testScheduler,
            itemForwarding: testItemForwarding
        )
        
        let log = createTestLog(body: "Real timeout test log")
        let expectation = XCTestExpectation(description: "Real timeout flush")
        
        // -- Act --
        sutWithRealQueue.addLog(log)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // -- Assert --
        XCTAssertEqual(testScheduler.captureLogsDataInvocations.count, 1, "Timeout should trigger flush")
        XCTAssertEqual(testScheduler.captureLogsDataInvocations.invocations.first?.telemetryType, .log)

        let capturedLogs = self.testScheduler.getCapturedLogs()
        XCTAssertEqual(capturedLogs.count, 1, "Should contain exactly one log")
        XCTAssertEqual(capturedLogs[0].body, "Real timeout test log")
    }

    // MARK: - Helper Methods
    
    private func createTestLog(
        level: SentryLog.Level = .info,
        body: String = "Test log message",
        attributes: [String: SentryLog.Attribute] = [:]
    ) -> SentryLog {
        return SentryLog(
            timestamp: Date(timeIntervalSince1970: 1_627_846_801),
            traceId: SentryId.empty,
            level: level,
            body: body,
            attributes: attributes
        )
    }
}

// MARK: - Test Helpers

final class TestLogTelemetryScheduler: TelemetryScheduler {
    var captureLogsDataInvocations = Invocations<(data: Data, count: Int, telemetryType: TelemetrySchedulerItemType)>()

    func capture(data: Data, count: Int, telemetryType: TelemetrySchedulerItemType) {
        captureLogsDataInvocations.record((data, count, telemetryType))
    }

    // Helper to get captured logs
    func getCapturedLogs() -> [SentryLog] {
        var allLogs: [SentryLog] = []
        
        for invocation in captureLogsDataInvocations.invocations {
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

// MARK: - Mock Item Forwarding

private class MockTelemetryBufferDataForwardingTriggers: TelemetryBufferItemForwardingTriggers {
    private weak var delegate: TelemetryBufferItemForwardingDelegate?

    func setDelegate(_ delegate: TelemetryBufferItemForwardingDelegate?) {
        self.delegate = delegate
    }

    func invokeDelegate() {
        delegate?.forwardItems()
    }
}
