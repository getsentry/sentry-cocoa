@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

final class SentryLogBatcherTests: XCTestCase {
    
    private var options: Options!
    private var testDelegate: TestLogBatcherDelegate!
    private var testDispatchQueue: TestSentryDispatchQueueWrapper!
    private var sut: SentryLogBatcher!
    private var scope: Scope!
    
    override func setUp() {
        super.setUp()
        
        options = Options()
        options.dsn = TestConstants.dsnAsString(username: "SentryLogBatcherTests")
        options.enableLogs = true
        
        testDelegate = TestLogBatcherDelegate()
        testDispatchQueue = TestSentryDispatchQueueWrapper()
        testDispatchQueue.dispatchAsyncExecutesBlock = true // Execute encoding immediately
        
        sut = SentryLogBatcher(
            options: options,
            flushTimeout: 0.1, // Very small timeout for testing
            maxBufferSizeBytes: 800, // byte limit for testing (log with attributes ~390 bytes)
            dispatchQueue: testDispatchQueue
        )
        sut.delegate = testDelegate
        scope = Scope()
    }
    
    override func tearDown() {
        super.tearDown()
        testDelegate = nil
        testDispatchQueue = nil
        sut = nil
        scope = nil
    }
    
    // MARK: - Basic Functionality Tests
    
    func testAddMultipleLogs_BatchesTogether() throws {
        // Given
        let log1 = createTestLog(body: "Log 1")
        let log2 = createTestLog(body: "Log 2")
        
        // When
        sut.addLog(log1, scope: scope)
        sut.addLog(log2, scope: scope)
        
        // Then - no immediate flush since buffer not full
        XCTAssertEqual(testDelegate.captureLogsDataInvocations.count, 0)
        
        // Trigger flush manually
        sut.captureLogs()
        
        // Verify both logs are batched together
        XCTAssertEqual(testDelegate.captureLogsDataInvocations.count, 1)
        
        let capturedLogs = testDelegate.getCapturedLogs()
        XCTAssertEqual(capturedLogs.count, 2)
        XCTAssertEqual(capturedLogs[0].body, "Log 1")
        XCTAssertEqual(capturedLogs[1].body, "Log 2")
    }
    
    // MARK: - Buffer Size Tests
    
    func testBufferReachesMaxSize_FlushesImmediately() throws {
        // Given - create a log that will exceed the 500 byte limit
        let largeLogBody = String(repeating: "A", count: 600) // Larger than 500 byte limit
        let largeLog = createTestLog(body: largeLogBody)
        
        // When - add a log that exceeds buffer size
        sut.addLog(largeLog, scope: scope)
        
        // Then - should trigger immediate flush
        XCTAssertEqual(testDelegate.captureLogsDataInvocations.count, 1)
        
        // Verify the large log is sent
        let capturedLogs = testDelegate.getCapturedLogs()
        XCTAssertEqual(capturedLogs.count, 1)
        XCTAssertEqual(capturedLogs[0].body, largeLogBody)
    }
    
    // MARK: - Timeout Tests
    
    func testTimeout_FlushesAfterDelay() throws {
        // Given
        let log = createTestLog()
        
        // When
        sut.addLog(log, scope: scope)
        
        // Then - no immediate flush but timer should be started
        XCTAssertEqual(testDelegate.captureLogsDataInvocations.count, 0)
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.count, 1)
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.first?.interval, 0.1)
        
        // Manually trigger the timer to simulate timeout
        testDispatchQueue.invokeLastDispatchAfterWorkItem()
        
        // Verify flush occurred
        XCTAssertEqual(testDelegate.captureLogsDataInvocations.count, 1)
        let capturedLogs = testDelegate.getCapturedLogs()
        XCTAssertEqual(capturedLogs.count, 1)
    }
    
    func testAddingLogToEmptyBuffer_StartsTimer() throws {
        // Given
        let log1 = createTestLog(body: "Log 1")
        let log2 = createTestLog(body: "Log 2")
        
        // When - add first log to empty buffer
        sut.addLog(log1, scope: scope)
        
        // Then - timer should be started for first log
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.count, 1)
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.first?.interval, 0.1)
        
        // When - add second log to non-empty buffer
        sut.addLog(log2, scope: scope)
        
        // Then - no additional timer should be started
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.count, 1)
        
        // Should not flush immediately
        XCTAssertEqual(testDelegate.captureLogsDataInvocations.count, 0)
        
        // Manually trigger the timer
        testDispatchQueue.invokeLastDispatchAfterWorkItem()
        
        // Verify both logs are flushed together
        XCTAssertEqual(testDelegate.captureLogsDataInvocations.count, 1)
        let capturedLogs = testDelegate.getCapturedLogs()
        XCTAssertEqual(capturedLogs.count, 2)
    }
     
     // MARK: - Manual Capture Logs Tests
    
    func testManualCaptureLogs_CapturesImmediately() throws {
        // Given
        let log1 = createTestLog(body: "Log 1")
        let log2 = createTestLog(body: "Log 2")
        
        // When
        sut.addLog(log1, scope: scope)
        sut.addLog(log2, scope: scope)
        XCTAssertEqual(testDelegate.captureLogsDataInvocations.count, 0)
        
        sut.captureLogs()
        
        // Then
        XCTAssertEqual(testDelegate.captureLogsDataInvocations.count, 1)
        
        let capturedLogs = testDelegate.getCapturedLogs()
        XCTAssertEqual(capturedLogs.count, 2)
    }
    
    func testManualCaptureLogs_CancelsScheduledCapture() throws {
        // Given
        let log = createTestLog()
        
        // When
        sut.addLog(log, scope: scope)
        
        // Then - timer should be started
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.count, 1)
        let timerWorkItem = try XCTUnwrap(testDispatchQueue.dispatchAfterWorkItemInvocations.first?.workItem)
        
        // Manual flush immediately
        sut.captureLogs()
        XCTAssertEqual(testDelegate.captureLogsDataInvocations.count, 1, "Manual flush should work")
        
        // Try to trigger the timer work item (should not flush again since timer was cancelled)
        timerWorkItem.perform()
        
        // Then - no additional flush should occur (timer was cancelled by performFlush)
        XCTAssertEqual(testDelegate.captureLogsDataInvocations.count, 1, "Timer should be cancelled")
    }
    
    func testManualCaptureLogs_WithEmptyBuffer_DoesNothing() {
        // When
        sut.captureLogs()
        
        // Then
        XCTAssertEqual(testDelegate.captureLogsDataInvocations.count, 0)
    }
    
    // MARK: - Edge Cases Tests
    
    func testScheduledFlushAfterBufferAlreadyFlushed_DoesNothing() throws {
        // Given - create logs that will trigger size-based flush
        let largeLogBody = String(repeating: "B", count: 300)
        let log1 = createTestLog(body: largeLogBody)
        let log2 = createTestLog(body: largeLogBody) // Together > 500 bytes
        
        // When - add first log (starts timer)
        sut.addLog(log1, scope: scope)
        XCTAssertEqual(testDelegate.captureLogsDataInvocations.count, 0)
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.count, 1)
        let timerWorkItem = try XCTUnwrap(testDispatchQueue.dispatchAfterWorkItemInvocations.first?.workItem)
        
        // Add second log that triggers size-based flush
        sut.addLog(log2, scope: scope)
        XCTAssertEqual(testDelegate.captureLogsDataInvocations.count, 1)
        
        // Try to trigger the original timer work item (should not flush again)
        timerWorkItem.perform()
        
        // Then - no additional flush should occur
        XCTAssertEqual(testDelegate.captureLogsDataInvocations.count, 1)
    }
    
    func testAddLogAfterFlush_StartsNewBatch() throws {
        // Given
        let log1 = createTestLog(body: "Log 1")
        let log2 = createTestLog(body: "Log 2")
        
        // When
        sut.addLog(log1, scope: scope)
        sut.captureLogs()
        
        XCTAssertEqual(testDelegate.captureLogsDataInvocations.count, 1)
        
        sut.addLog(log2, scope: scope)
        sut.captureLogs()
        
        // Then - should have two separate flush calls
        XCTAssertEqual(testDelegate.captureLogsDataInvocations.count, 2)
        
        // Verify each flush contains only one log
        let allCapturedLogs = testDelegate.getCapturedLogs()
        XCTAssertEqual(allCapturedLogs.count, 2)
        XCTAssertEqual(allCapturedLogs[0].body, "Log 1")
        XCTAssertEqual(allCapturedLogs[1].body, "Log 2")
    }
    
    // MARK: - Integration Tests
    
    func testConcurrentAdds_ThreadSafe() throws {
        // Given
        let sutWithRealQueue = SentryLogBatcher(
            options: options,
            flushTimeout: 5,
            maxBufferSizeBytes: 10_000, // Large buffer to avoid immediate flushes
            dispatchQueue: SentryDispatchQueueWrapper() // Real dispatch queue
        )
        sutWithRealQueue.delegate = testDelegate
        
        let expectation = XCTestExpectation(description: "Concurrent adds")
        expectation.expectedFulfillmentCount = 10
        
        // When - add logs concurrently from multiple threads
        for i in 0..<10 {
            DispatchQueue.global().async {
                let log = self.createTestLog(body: "Log \(i)")
                sutWithRealQueue.addLog(log, scope: self.scope)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 1.0)
                
        sutWithRealQueue.captureLogs()
        
        // Verify all 10 logs were included in the batch
        let capturedLogs = self.testDelegate.getCapturedLogs()
        XCTAssertEqual(capturedLogs.count, 10, "All 10 concurrently added logs should be in the batch")
        // Note: We can't verify exact order due to concurrency, but count should be correct
    }

    func testDispatchAfterTimeoutWithRealDispatchQueue() throws {
        // Given - create batcher with real dispatch queue and short timeout
        let sutWithRealQueue = SentryLogBatcher(
            options: options,
            flushTimeout: 0.2, // Short but realistic timeout
            maxBufferSizeBytes: 10_000, // Large buffer to avoid size-based flush
            dispatchQueue: SentryDispatchQueueWrapper() // Real dispatch queue
        )
        sutWithRealQueue.delegate = testDelegate
        
        let log = createTestLog(body: "Real timeout test log")
        let expectation = XCTestExpectation(description: "Real timeout flush")
        
        // When - add log and wait for real timeout
        sutWithRealQueue.addLog(log, scope: scope)
        
        // Initially no flush should have occurred
        XCTAssertEqual(testDelegate.captureLogsDataInvocations.count, 0)
        
        // Wait for timeout to trigger flush
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { // Wait longer than timeout
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Then - verify flush occurred due to timeout
        XCTAssertEqual(testDelegate.captureLogsDataInvocations.count, 1, "Timeout should trigger flush")
        
        let capturedLogs = self.testDelegate.getCapturedLogs()
        XCTAssertEqual(capturedLogs.count, 1, "Should contain exactly one log")
        XCTAssertEqual(capturedLogs[0].body, "Real timeout test log")
    }
    
    // MARK: - Attribute Enrichment Tests
    
    func testAddLog_AddsDefaultAttributes() {
        options.environment = "test-environment"
        options.releaseName = "1.0.0"
        
        let span = SentryTracer(transactionContext: TransactionContext(name: "Test Transaction", operation: "test-operation"), hub: nil)
        scope.span = span
        
        let log = createTestLog(body: "Test log message")
        sut.addLog(log, scope: scope)
        sut.captureLogs()
        
        // Verify the log was batched and sent
        let capturedLogs = testDelegate.getCapturedLogs()
        XCTAssertEqual(capturedLogs.count, 1)
        
        let capturedLog = capturedLogs.first!
        let attributes = capturedLog.attributes
        
        XCTAssertEqual(attributes["sentry.sdk.name"]?.value as? String, SentryMeta.sdkName)
        XCTAssertEqual(attributes["sentry.sdk.version"]?.value as? String, SentryMeta.versionString)
        XCTAssertEqual(attributes["sentry.environment"]?.value as? String, "test-environment")
        XCTAssertEqual(attributes["sentry.release"]?.value as? String, "1.0.0")
        XCTAssertEqual(attributes["sentry.trace.parent_span_id"]?.value as? String, span.spanId.sentrySpanIdString)
    }
    
    func testAddLog_DoesNotAddNilDefaultAttributes() {
        options.releaseName = nil
        // No span set on scope
        
        let log = createTestLog(body: "Test log message")
        sut.addLog(log, scope: scope)
        sut.captureLogs()
        
        let capturedLogs = testDelegate.getCapturedLogs()
        let capturedLog = capturedLogs.first!
        let attributes = capturedLog.attributes
        
        XCTAssertNil(attributes["sentry.release"])
        XCTAssertNil(attributes["sentry.trace.parent_span_id"])
        
        // But should still have the non-nil defaults
        XCTAssertEqual(attributes["sentry.sdk.name"]?.value as? String, SentryMeta.sdkName)
        XCTAssertEqual(attributes["sentry.sdk.version"]?.value as? String, SentryMeta.versionString)
        XCTAssertNotNil(attributes["sentry.environment"])
    }
    
    func testAddLog_SetsTraceIdFromPropagationContext() {
        let expectedTraceId = SentryId()
        let propagationContext = SentryPropagationContext(trace: expectedTraceId, spanId: SpanId())
        scope.propagationContext = propagationContext
        
        let log = createTestLog(body: "Test log message with trace ID")
        sut.addLog(log, scope: scope)
        sut.captureLogs()
        
        let capturedLogs = testDelegate.getCapturedLogs()
        let capturedLog = capturedLogs.first!
        XCTAssertEqual(capturedLog.traceId, expectedTraceId)
    }
    
    func testAddLog_AddsUserAttributes() {
        let user = User()
        user.userId = "123"
        user.email = "test@test.com"
        user.name = "test-name"
        scope.setUser(user)
        
        let log = createTestLog(body: "Test log message with user")
        sut.addLog(log, scope: scope)
        sut.captureLogs()
        
        let capturedLogs = testDelegate.getCapturedLogs()
        let capturedLog = capturedLogs.first!
        let attributes = capturedLog.attributes
        
        XCTAssertEqual(attributes["user.id"]?.value as? String, "123")
        XCTAssertEqual(attributes["user.name"]?.value as? String, "test-name")
        XCTAssertEqual(attributes["user.email"]?.value as? String, "test@test.com")
    }
    
    func testAddLog_DoesNotAddNilUserAttributes() {
        let user = User()
        user.userId = "123"
        // email and name are nil
        scope.setUser(user)
        
        let log = createTestLog(body: "Test log message with partial user")
        sut.addLog(log, scope: scope)
        sut.captureLogs()
        
        let capturedLogs = testDelegate.getCapturedLogs()
        let capturedLog = capturedLogs.first!
        let attributes = capturedLog.attributes
        
        XCTAssertEqual(attributes["user.id"]?.value as? String, "123")
        XCTAssertNil(attributes["user.name"])
        XCTAssertNil(attributes["user.email"])
    }
    
    func testAddLog_DoesNotAddUserAttributesWhenNoUser() {
        // No user set on scope
        
        let log = createTestLog(body: "Test log message without user")
        sut.addLog(log, scope: scope)
        sut.captureLogs()
        
        let capturedLogs = testDelegate.getCapturedLogs()
        let capturedLog = capturedLogs.first!
        let attributes = capturedLog.attributes
        
        XCTAssertNil(attributes["user.id"])
        XCTAssertNil(attributes["user.name"])
        XCTAssertNil(attributes["user.email"])
    }
    
    func testAddLog_AddsOSAndDeviceAttributes() {
        let osContext = ["name": "iOS", "version": "16.0.1"]
        let deviceContext = ["family": "iOS", "model": "iPhone14,4"]
        
        scope.setContext(value: osContext, key: "os")
        scope.setContext(value: deviceContext, key: "device")
        
        let log = createTestLog(body: "Test log message")
        sut.addLog(log, scope: scope)
        sut.captureLogs()
        
        let capturedLogs = testDelegate.getCapturedLogs()
        let capturedLog = capturedLogs.first!
        let attributes = capturedLog.attributes
        
        XCTAssertEqual(attributes["os.name"]?.value as? String, "iOS")
        XCTAssertEqual(attributes["os.version"]?.value as? String, "16.0.1")
        XCTAssertEqual(attributes["device.brand"]?.value as? String, "Apple")
        XCTAssertEqual(attributes["device.model"]?.value as? String, "iPhone14,4")
        XCTAssertEqual(attributes["device.family"]?.value as? String, "iOS")
    }
    
    func testAddLog_HandlesPartialOSAndDeviceAttributes() {
        let osContext = ["name": "macOS"] // Missing version
        let deviceContext = ["family": "macOS"] // Missing model
        
        scope.setContext(value: osContext, key: "os")
        scope.setContext(value: deviceContext, key: "device")
        
        let log = createTestLog(body: "Test log message")
        sut.addLog(log, scope: scope)
        sut.captureLogs()
        
        let capturedLogs = testDelegate.getCapturedLogs()
        let capturedLog = capturedLogs.first!
        let attributes = capturedLog.attributes
        
        XCTAssertEqual(attributes["os.name"]?.value as? String, "macOS")
        XCTAssertNil(attributes["os.version"])
        XCTAssertEqual(attributes["device.brand"]?.value as? String, "Apple")
        XCTAssertNil(attributes["device.model"])
        XCTAssertEqual(attributes["device.family"]?.value as? String, "macOS")
    }
    
    func testAddLog_HandlesMissingOSAndDeviceContext() {
        // Clear any OS and device context
        scope.removeContext(key: "os")
        scope.removeContext(key: "device")
        
        let log = createTestLog(body: "Test log message")
        sut.addLog(log, scope: scope)
        sut.captureLogs()
        
        let capturedLogs = testDelegate.getCapturedLogs()
        let capturedLog = capturedLogs.first!
        let attributes = capturedLog.attributes
        
        XCTAssertNil(attributes["os.name"])
        XCTAssertNil(attributes["os.version"])
        XCTAssertNil(attributes["device.brand"])
        XCTAssertNil(attributes["device.model"])
        XCTAssertNil(attributes["device.family"])
    }
    
    // MARK: - BeforeSendLog Callback Tests
    
    func testBeforeSendLog_ReturnsModifiedLog() {
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
        
        let log = createTestLog(level: .info, body: "Original message")
        sut.addLog(log, scope: scope)
        sut.captureLogs()
        
        XCTAssertTrue(beforeSendCalled)
        
        let capturedLogs = testDelegate.getCapturedLogs()
        let capturedLog = capturedLogs.first!
        XCTAssertEqual(capturedLog.level, .warn)
        XCTAssertEqual(capturedLog.body, "Modified by callback")
        XCTAssertEqual(capturedLog.attributes["callback_modified"]?.value as? Bool, true)
    }
    
    func testBeforeSendLog_ReturnsNil_LogNotCaptured() {
        var beforeSendCalled = false
        options.beforeSendLog = { _ in
            beforeSendCalled = true
            return nil // Drop the log
        }
        
        let log = createTestLog(body: "This log should be dropped")
        sut.addLog(log, scope: scope)
        sut.captureLogs()
        
        XCTAssertTrue(beforeSendCalled)
        XCTAssertEqual(testDelegate.captureLogsDataInvocations.count, 0)
    }
    
    func testBeforeSendLog_NotSet_LogCapturedUnmodified() {
        options.beforeSendLog = nil
        
        let log = createTestLog(level: .debug, body: "Debug message")
        sut.addLog(log, scope: scope)
        sut.captureLogs()
        
        let capturedLogs = testDelegate.getCapturedLogs()
        XCTAssertEqual(capturedLogs.count, 1)
        
        let capturedLog = capturedLogs.first!
        XCTAssertEqual(capturedLog.level, .debug)
        XCTAssertEqual(capturedLog.body, "Debug message")
    }
    
    func testBeforeSendLog_PreservesOriginalLogAttributes() {
        options.beforeSendLog = { log in
            log.attributes["added_by_callback"] = SentryLog.Attribute(string: "callback_value")
            return log
        }
        
        let logAttributes: [String: SentryLog.Attribute] = [
            "original_key": SentryLog.Attribute(string: "original_value"),
            "user_id": SentryLog.Attribute(integer: 12_345)
        ]
        
        let log = createTestLog(body: "Test message", attributes: logAttributes)
        sut.addLog(log, scope: scope)
        sut.captureLogs()
        
        let capturedLogs = testDelegate.getCapturedLogs()
        let capturedLog = capturedLogs.first!
        let attributes = capturedLog.attributes
        
        XCTAssertEqual(attributes["original_key"]?.value as? String, "original_value")
        XCTAssertEqual(attributes["user_id"]?.value as? Int, 12_345)
        XCTAssertEqual(attributes["added_by_callback"]?.value as? String, "callback_value")
    }
    
    func testBeforeSendLogCallback_DynamicAccessGetAndSet() {
        // Test dynamic access can both set and get the callback
        let originalCallback: (SentryLog) -> SentryLog? = { log in
            log.body = "Modified by original callback"
            return log
        }
        
        // Set using dynamic access
        options.setValue(originalCallback, forKey: "beforeSendLogDynamic")
        
        // Get using dynamic access and verify it's the same callback
        let retrievedCallback = options.value(forKey: "beforeSendLogDynamic") as? (SentryLog) -> SentryLog?
        XCTAssertNotNil(retrievedCallback, "Dynamic access should retrieve the callback")
        
        let log = SentryLog(timestamp: Date(), traceId: .empty, level: .info, body: "foo", attributes: [:])
        let modifiedLog = retrievedCallback?(log)
        
        XCTAssertEqual(modifiedLog?.body, "Modified by original callback")
        
        // Test setting to nil using dynamic access
        options.setValue(nil, forKey: "beforeSendLogDynamic")
        let nilCallback = options.value(forKey: "beforeSendLogDynamic")
        XCTAssertNil(nilCallback, "Dynamic access should allow setting to nil")
    }
    
    func testAddLog_WithLogsDisabled_DoesNotCaptureLog() {
        // Given - logs are disabled
        options.enableLogs = false
        
        let log = createTestLog(body: "This log should be ignored")
        
        // When
        sut.addLog(log, scope: scope)
        sut.captureLogs()
        
        // Then - no logs should be captured when logs are disabled
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

final class TestLogBatcherDelegate: NSObject, SentryLogBatcherDelegate {
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
