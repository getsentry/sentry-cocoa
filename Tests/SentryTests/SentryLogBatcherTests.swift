@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

final class SentryLogBatcherTests: XCTestCase {
    
    private var options: Options!
    private var testClient: TestClient!
    private var testDispatchQueue: TestSentryDispatchQueueWrapper!
    private var sut: SentryLogBatcher!
    private var scope: Scope!
    
    override func setUp() {
        super.setUp()
        
        options = Options()
        options.experimental.enableLogs = true
        
        testClient = TestClient(options: options)
        testDispatchQueue = TestSentryDispatchQueueWrapper()
        testDispatchQueue.dispatchAsyncExecutesBlock = true // Execute encoding immediately
        
        sut = SentryLogBatcher(
            client: testClient,
            flushTimeout: 0.1, // Very small timeout for testing
            maxBufferSizeBytes: 500, // Small byte limit for testing
            dispatchQueue: testDispatchQueue
        )
        scope = Scope()
    }
    
    override func tearDown() {
        super.tearDown()
        testClient = nil
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
        sut.add(log1)
        sut.add(log2)
        
        // Then - no immediate flush since buffer not full
        XCTAssertEqual(testClient.captureLogsDataInvocations.count, 0)
        
        // Trigger flush manually
        sut.flush()
        
        // Verify both logs are batched together
        XCTAssertEqual(testClient.captureLogsDataInvocations.count, 1)
        let sentData = try XCTUnwrap(testClient.captureLogsDataInvocations.first).data
        let jsonObject = try XCTUnwrap(JSONSerialization.jsonObject(with: sentData) as? [String: Any])
        let items = try XCTUnwrap(jsonObject["items"] as? [[String: Any]])
        XCTAssertEqual(2, items.count)
    }
    
    // MARK: - Buffer Size Tests
    
    func testBufferReachesMaxSize_FlushesImmediately() throws {
        // Given - create a log that will exceed the 500 byte limit
        let largeLogBody = String(repeating: "A", count: 600) // Larger than 500 byte limit
        let largeLog = createTestLog(body: largeLogBody)
        
        // When - add a log that exceeds buffer size
        sut.add(largeLog)
        
        // Then - should trigger immediate flush
        XCTAssertEqual(testClient.captureLogsDataInvocations.count, 1)
        
        // Verify the large log is sent
        let sentData = try XCTUnwrap(testClient.captureLogsDataInvocations.first).data
        let jsonObject = try XCTUnwrap(JSONSerialization.jsonObject(with: sentData) as? [String: Any])
        let items = try XCTUnwrap(jsonObject["items"] as? [[String: Any]])
        XCTAssertEqual(1, items.count)
        XCTAssertEqual(largeLogBody, items[0]["body"] as? String)
    }
    
    // MARK: - Timeout Tests
    
    func testTimeout_FlushesAfterDelay() throws {
        // Given
        let log = createTestLog()
        
        // When
        sut.add(log)
        
        // Then - no immediate flush but timer should be started
        XCTAssertEqual(testClient.captureLogsDataInvocations.count, 0)
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.count, 1)
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.first?.interval, 0.1)
        
        // Manually trigger the timer to simulate timeout
        testDispatchQueue.invokeLastDispatchAfterWorkItem()
        
        // Verify flush occurred
        XCTAssertEqual(testClient.captureLogsDataInvocations.count, 1)
        let sentData = try XCTUnwrap(testClient.captureLogsDataInvocations.first).data
        let jsonObject = try XCTUnwrap(JSONSerialization.jsonObject(with: sentData) as? [String: Any])
        let items = try XCTUnwrap(jsonObject["items"] as? [[String: Any]])
        XCTAssertEqual(1, items.count)
    }
    
    func testAddingLogToEmptyBuffer_StartsTimer() throws {
        // Given
        let log1 = createTestLog(body: "Log 1")
        let log2 = createTestLog(body: "Log 2")
        
        // When - add first log to empty buffer
        sut.add(log1)
        
        // Then - timer should be started for first log
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.count, 1)
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.first?.interval, 0.1)
        
        // When - add second log to non-empty buffer
        sut.add(log2)
        
        // Then - no additional timer should be started
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.count, 1)
        
        // Should not flush immediately
        XCTAssertEqual(testClient.captureLogsDataInvocations.count, 0)
        
        // Manually trigger the timer
        testDispatchQueue.invokeLastDispatchAfterWorkItem()
        
        // Verify both logs are flushed together
        XCTAssertEqual(testClient.captureLogsDataInvocations.count, 1)
        let sentData = try XCTUnwrap(testClient.captureLogsDataInvocations.first).data
        let jsonObject = try XCTUnwrap(JSONSerialization.jsonObject(with: sentData) as? [String: Any])
        let items = try XCTUnwrap(jsonObject["items"] as? [[String: Any]])
        XCTAssertEqual(2, items.count)
    }
     
     // MARK: - Manual Flush Tests
    
    func testManualFlush_FlushesImmediately() throws {
        // Given
        let log1 = createTestLog(body: "Log 1")
        let log2 = createTestLog(body: "Log 2")
        
        // When
        sut.add(log1)
        sut.add(log2)
        XCTAssertEqual(testClient.captureLogsDataInvocations.count, 0)
        
        sut.flush()
        
        // Then
        XCTAssertEqual(testClient.captureLogsDataInvocations.count, 1)
        
        let sentData = try XCTUnwrap(testClient.captureLogsDataInvocations.first).data
        let jsonObject = try XCTUnwrap(JSONSerialization.jsonObject(with: sentData) as? [String: Any])
        let items = try XCTUnwrap(jsonObject["items"] as? [[String: Any]])
        XCTAssertEqual(2, items.count)
    }
    
    func testManualFlush_CancelsScheduledFlush() throws {
        // Given
        let log = createTestLog()
        
        // When
        sut.add(log)
        
        // Then - timer should be started
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.count, 1)
        let timerWorkItem = try XCTUnwrap(testDispatchQueue.dispatchAfterWorkItemInvocations.first?.workItem)
        
        // Manual flush immediately
        sut.flush()
        XCTAssertEqual(testClient.captureLogsDataInvocations.count, 1, "Manual flush should work")
        
        // Try to trigger the timer work item (should not flush again since timer was cancelled)
        timerWorkItem.perform()
        
        // Then - no additional flush should occur (timer was cancelled by performFlush)
        XCTAssertEqual(testClient.captureLogsDataInvocations.count, 1, "Timer should be cancelled")
    }
    
    func testFlushEmptyBuffer_DoesNothing() {
        // When
        sut.flush()
        
        // Then
        XCTAssertEqual(testClient.captureLogsDataInvocations.count, 0)
    }

    // MARK: - Edge Cases Tests
    
    func testScheduledFlushAfterBufferAlreadyFlushed_DoesNothing() throws {
        // Given - create logs that will trigger size-based flush
        let largeLogBody = String(repeating: "B", count: 300)
        let log1 = createTestLog(body: largeLogBody)
        let log2 = createTestLog(body: largeLogBody) // Together > 500 bytes
        
        // When - add first log (starts timer)
        sut.add(log1)
        XCTAssertEqual(testClient.captureLogsDataInvocations.count, 0)
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.count, 1)
        let timerWorkItem = try XCTUnwrap(testDispatchQueue.dispatchAfterWorkItemInvocations.first?.workItem)
        
        // Add second log that triggers size-based flush
        sut.add(log2)
        XCTAssertEqual(testClient.captureLogsDataInvocations.count, 1)
        
        // Try to trigger the original timer work item (should not flush again)
        timerWorkItem.perform()
        
        // Then - no additional flush should occur
        XCTAssertEqual(testClient.captureLogsDataInvocations.count, 1)
    }
    
    func testAddLogAfterFlush_StartsNewBatch() throws {
        // Given
        let log1 = createTestLog(body: "Log 1")
        let log2 = createTestLog(body: "Log 2")
        
        // When
        sut.add(log1)
        sut.flush()
        
        XCTAssertEqual(testClient.captureLogsDataInvocations.count, 1)
        
        sut.add(log2)
        sut.flush()
        
        // Then - should have two separate flush calls
        XCTAssertEqual(testClient.captureLogsDataInvocations.count, 2)
        
        // Verify each flush contains only one log
        for (index, invocation) in testClient.captureLogsDataInvocations.invocations.enumerated() {
            let jsonObject = try XCTUnwrap(JSONSerialization.jsonObject(with: invocation.data) as? [String: Any])
            let items = try XCTUnwrap(jsonObject["items"] as? [[String: Any]])
            XCTAssertEqual(1, items.count)
            XCTAssertEqual("Log \(index + 1)", items[0]["body"] as? String)
        }
    }
    
    // MARK: - IntegrationTests
    
    func testConcurrentAdds_ThreadSafe() throws {
        // Given
        let sutWithRealQueue = SentryLogBatcher(
            client: testClient,
            flushTimeout: 5,
            maxBufferSizeBytes: 10_000, // Large buffer to avoid immediate flushes
            dispatchQueue: SentryDispatchQueueWrapper() // Real dispatch queue
        )
        
        let expectation = XCTestExpectation(description: "Concurrent adds")
        expectation.expectedFulfillmentCount = 10
        
        // When - add logs concurrently from multiple threads
        for i in 0..<10 {
            DispatchQueue.global().async {
                let log = self.createTestLog(body: "Log \(i)")
                sutWithRealQueue.add(log)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 1.0)
                
        sutWithRealQueue.flush()
        
        // Need to wait a bit for flush to complete since this uses a real queue
        let flushExpectation = self.expectation(description: "Wait for flush")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            flushExpectation.fulfill()
        }
        waitForExpectations(timeout: 0.5)
        
        // Verify all 10 logs were included in the single batch
        let sentData = try XCTUnwrap(testClient.captureLogsDataInvocations.first).data
        let jsonObject = try XCTUnwrap(JSONSerialization.jsonObject(with: sentData) as? [String: Any])
        let items = try XCTUnwrap(jsonObject["items"] as? [[String: Any]])
        XCTAssertEqual(10, items.count, "All 10 concurrently added logs should be in the batch")
        // Note: We can't verify exact order due to concurrency, but count should be correct
    }

    func testDispatchAfterTimeoutWithRealDispatchQueue() throws {
        // Given - create batcher with real dispatch queue and short timeout
        let sutWithRealQueue = SentryLogBatcher(
            client: testClient,
            flushTimeout: 0.2, // Short but realistic timeout
            maxBufferSizeBytes: 10_000, // Large buffer to avoid size-based flush
            dispatchQueue: SentryDispatchQueueWrapper() // Real dispatch queue
        )
        
        let log = createTestLog(body: "Real timeout test log")
        let expectation = XCTestExpectation(description: "Real timeout flush")
        
        // When - add log and wait for real timeout
        sutWithRealQueue.add(log)
        
        // Initially no flush should have occurred
        XCTAssertEqual(testClient.captureLogsDataInvocations.count, 0)
        
        // Wait for timeout to trigger flush
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { // Wait longer than timeout
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Then - verify flush occurred due to timeout
        XCTAssertEqual(testClient.captureLogsDataInvocations.count, 1, "Timeout should trigger flush")
        
        let sentData = try XCTUnwrap(testClient.captureLogsDataInvocations.first).data
        let jsonObject = try XCTUnwrap(JSONSerialization.jsonObject(with: sentData) as? [String: Any])
        let items = try XCTUnwrap(jsonObject["items"] as? [[String: Any]])
        XCTAssertEqual(1, items.count, "Should contain exactly one log")
        XCTAssertEqual("Real timeout test log", items[0]["body"] as? String)
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
