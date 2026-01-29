@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

final class SentryLogBufferTests: XCTestCase {

    private var options: Options!
    private var testDateProvider: TestCurrentDateProvider!
    private var testDelegate: TestLogBufferDelegate!
    private var testDispatchQueue: TestSentryDispatchQueueWrapper!
    private var scope: Scope!

    private func getSut() -> SentryLogBuffer {
        return SentryLogBuffer(
            options: options,
            flushTimeout: 0.1, // Very small timeout for testing
            maxLogCount: 10, // Maximum 10 logs per batch
            maxBufferSizeBytes: 8_000, // byte limit for testing (log with attributes ~390 bytes)
            dateProvider: testDateProvider,
            dispatchQueue: testDispatchQueue,
            delegate: testDelegate
        )
    }

    override func setUp() {
        super.setUp()
        
        options = Options()
        options.dsn = TestConstants.dsnForTestCase(type: Self.self)
        options.enableLogs = true

        testDateProvider = TestCurrentDateProvider()
        testDelegate = TestLogBufferDelegate()
        testDispatchQueue = TestSentryDispatchQueueWrapper()
        testDispatchQueue.dispatchAsyncExecutesBlock = true // Execute encoding immediately
        
        scope = Scope()
    }
    
    override func tearDown() {
        super.tearDown()
        testDelegate = nil
        testDispatchQueue = nil
        scope = nil
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
        XCTAssertEqual(testDelegate.captureLogsDataInvocations.count, 1)
        
        let capturedLogs = testDelegate.getCapturedLogs()
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
        XCTAssertEqual(testDelegate.captureLogsDataInvocations.count, 1)
        
        let capturedLogs = testDelegate.getCapturedLogs()
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
        
        XCTAssertEqual(testDelegate.captureLogsDataInvocations.count, 0)
        
        let log = createTestLog(body: "Log \(10)") // Reached 10 max logs limit
        sut.addLog(log)
        
        // -- Assert --
        XCTAssertEqual(testDelegate.captureLogsDataInvocations.count, 1)
        
        let capturedLogs = testDelegate.getCapturedLogs()
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
        XCTAssertEqual(testDelegate.captureLogsDataInvocations.count, 1)
        
        let capturedLogs = testDelegate.getCapturedLogs()
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
        XCTAssertEqual(testDelegate.captureLogsDataInvocations.count, 1)
        
        let capturedLogs = testDelegate.getCapturedLogs()
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
        XCTAssertEqual(testDelegate.captureLogsDataInvocations.count, 1)
        
        let capturedLogs = testDelegate.getCapturedLogs()
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
        XCTAssertEqual(testDelegate.captureLogsDataInvocations.count, 1, "Manual flush should work and timer should be cancelled")
    }
    
    func testManualCaptureLogs_WithEmptyBuffer_DoesNothing() {
        // -- Arrange --
        let sut = getSut()
        
        // -- Act --
        sut.captureLogs()
        
        // -- Assert --
        XCTAssertEqual(testDelegate.captureLogsDataInvocations.count, 0)
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
        XCTAssertEqual(testDelegate.captureLogsDataInvocations.count, 1)
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
        XCTAssertEqual(testDelegate.captureLogsDataInvocations.count, 2)
        
        let allCapturedLogs = testDelegate.getCapturedLogs()
        XCTAssertEqual(allCapturedLogs.count, 2)
        XCTAssertEqual(allCapturedLogs[0].body, "Log 1")
        XCTAssertEqual(allCapturedLogs[1].body, "Log 2")
    }
    
    // MARK: - Integration Tests
    
    func testConcurrentAdds_ThreadSafe() throws {
        // -- Arrange --
        let sutWithRealQueue = SentryLogBuffer(
            options: options,
            flushTimeout: 5,
            maxLogCount: 1_000, // Maximum 1000 logs per batch
            maxBufferSizeBytes: 10_000,
            dateProvider: testDateProvider,
            dispatchQueue: SentryDispatchQueueWrapper(),
            delegate: testDelegate
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
        let capturedLogs = self.testDelegate.getCapturedLogs()
        XCTAssertEqual(capturedLogs.count, 10, "All 10 concurrently added logs should be in the batch")
    }

    func testDispatchAfterTimeoutWithRealDispatchQueue() throws {
        // -- Arrange --
        let sutWithRealQueue = SentryLogBuffer(
            options: options,
            flushTimeout: 0.2,
            maxLogCount: 1_000, // Maximum 1000 logs per batch
            maxBufferSizeBytes: 10_000,
            dateProvider: testDateProvider,
            dispatchQueue: SentryDispatchQueueWrapper(),
            delegate: testDelegate
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
        XCTAssertEqual(testDelegate.captureLogsDataInvocations.count, 1, "Timeout should trigger flush")
        
        let capturedLogs = self.testDelegate.getCapturedLogs()
        XCTAssertEqual(capturedLogs.count, 1, "Should contain exactly one log")
        XCTAssertEqual(capturedLogs[0].body, "Real timeout test log")
    }
    
    // MARK: - BeforeSendLog Callback Tests
    
    func testBeforeSendLog_ReturnsModifiedLog() throws {
        // -- Arrange --
        var beforeSendCalled = false
        options.beforeSendLog = { log in
            beforeSendCalled = true
            
            XCTAssertEqual(log.level, .info)
            XCTAssertEqual(log.body, "Original message")
            
            log.body = "Modified by callback"
            log.level = .warn
            log.attributes["callback_modified"] = SentryLog.Attribute(boolean: true)
            
            return log
        }
        let sut = getSut()
        let log = createTestLog(level: .info, body: "Original message")

        // -- Act --
        sut.addLog(log)
        sut.captureLogs()
        
        // -- Assert --
        XCTAssertTrue(beforeSendCalled)
        
        let capturedLogs = testDelegate.getCapturedLogs()
        let capturedLog = try XCTUnwrap(capturedLogs.first)
        XCTAssertEqual(capturedLog.level, .warn)
        XCTAssertEqual(capturedLog.body, "Modified by callback")
        XCTAssertEqual(capturedLog.attributes["callback_modified"]?.value as? Bool, true)
    }
    
    func testBeforeSendLog_ReturnsNil_LogNotCaptured() {
        // -- Arrange --
        var beforeSendCalled = false
        options.beforeSendLog = { _ in
            beforeSendCalled = true
            return nil // Drop the log
        }
        let sut = getSut()
        let log = createTestLog(body: "This log should be dropped")
        
        // -- Act --
        sut.addLog(log)
        sut.captureLogs()
        
        // -- Assert --
        XCTAssertTrue(beforeSendCalled)
        XCTAssertEqual(testDelegate.captureLogsDataInvocations.count, 0)
    }
    
    func testBeforeSendLog_NotSet_LogCapturedUnmodified() throws {
        // -- Arrange --
        options.beforeSendLog = nil
        let sut = getSut()
        let log = createTestLog(level: .debug, body: "Debug message")
        
        // -- Act --
        sut.addLog(log)
        sut.captureLogs()
        
        // -- Assert --
        let capturedLogs = testDelegate.getCapturedLogs()
        XCTAssertEqual(capturedLogs.count, 1)
        
        let capturedLog = try XCTUnwrap(capturedLogs.first)
        XCTAssertEqual(capturedLog.level, .debug)
        XCTAssertEqual(capturedLog.body, "Debug message")
    }
    
    func testBeforeSendLog_PreservesOriginalLogAttributes() throws {
        // -- Arrange --
        options.beforeSendLog = { log in
            log.attributes["added_by_callback"] = SentryLog.Attribute(string: "callback_value")
            return log
        }
        let sut = getSut()
        
        let logAttributes: [String: SentryLog.Attribute] = [
            "original_key": SentryLog.Attribute(string: "original_value"),
            "user_id": SentryLog.Attribute(integer: 12_345)
        ]
        let log = createTestLog(body: "Test message", attributes: logAttributes)
        
        // -- Act --
        sut.addLog(log)
        sut.captureLogs()
        
        // -- Assert --
        let capturedLogs = testDelegate.getCapturedLogs()
        let capturedLog = try XCTUnwrap(capturedLogs.first)
        let attributes = capturedLog.attributes
        
        XCTAssertEqual(attributes["original_key"]?.value as? String, "original_value")
        XCTAssertEqual(attributes["user_id"]?.value as? Int, 12_345)
        XCTAssertEqual(attributes["added_by_callback"]?.value as? String, "callback_value")
    }
    
    func testAddLog_WithLogsDisabled_DoesNotCaptureLog() {
        // -- Arrange --
        options.enableLogs = false
        let sut = getSut()
        let log = createTestLog(body: "This log should be ignored")
        
        // -- Act --
        sut.addLog(log)
        sut.captureLogs()
        
        // -- Assert --
        XCTAssertEqual(testDelegate.captureLogsDataInvocations.count, 0)
        let capturedLogs = testDelegate.getCapturedLogs()
        XCTAssertEqual(capturedLogs.count, 0)
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

final class TestLogBufferDelegate: NSObject, SentryLogBufferDelegate {
    var captureLogsDataInvocations = Invocations<(data: Data, count: NSNumber)>()
    
    func capture(logsData: NSData, count: NSNumber) {
        captureLogsDataInvocations.record((logsData as Data, count))
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
