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
        
        // Async, wait a bit.
        waitBeforeTimeout()
        
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
        
        // Async, wait a bit.
        waitBeforeTimeout()
        
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
        
        // Async, wait a bit.
        waitBeforeTimeout()
        
        // Then - no immediate flush
        XCTAssertEqual(testClient.captureLogsDataInvocations.count, 0)
        
        // Wait enough time for timet to fire
        waitAfterTimeout()
        
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
        
        // When - add logs
        sut.add(log1)
        sut.add(log2)
        
        // Should not flush immediately
        XCTAssertEqual(testClient.captureLogsDataInvocations.count, 0)
        
        waitAfterTimeout()
        
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
        
        // Async, wait a bit.
        waitBeforeTimeout()
        
        // Then - manual flush dispatches async, so it executes immediately with test setup
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
        
        // Manual flush immediately
        sut.flush()
        XCTAssertEqual(testClient.captureLogsDataInvocations.count, 1, "Manual flush should work")
        
        // Wait for any timer that might have been scheduled to potentially fire
        waitAfterTimeout()
        
        // Then - no additional flush should occur (timer was cancelled by performFlush)
        XCTAssertEqual(testClient.captureLogsDataInvocations.count, 1, "Timer should be cancelled")
    }
    
    func testFlushEmptyBuffer_DoesNothing() {
        // When
        sut.flush()
        
        // Async, wait a bit.
        waitBeforeTimeout()
        
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
        
        // Add second log that triggers size-based flush
        sut.add(log2)
        XCTAssertEqual(testClient.captureLogsDataInvocations.count, 1)
        
        // Wait for any timer that might have been scheduled to potentially fire
        waitAfterTimeout()
        
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
        waitBeforeTimeout()
        
        XCTAssertEqual(testClient.captureLogsDataInvocations.count, 1)
        
        sut.add(log2)
        sut.flush()
        waitBeforeTimeout()
        
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
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentAdds_ThreadSafe() throws {
        // Given
        let sutWithRealQueue = SentryLogBatcher(
            client: testClient,
            flushTimeout: 5,
            maxBufferSizeBytes: 10_000, // Large buffer to avoid immediate flushes
            dispatchQueue: SentryDispatchQueueWrapper()
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
        waitBeforeTimeout()
        
        // Verify all 10 logs were included in the single batch
        let sentData = try XCTUnwrap(testClient.captureLogsDataInvocations.first).data
        let jsonObject = try XCTUnwrap(JSONSerialization.jsonObject(with: sentData) as? [String: Any])
        let items = try XCTUnwrap(jsonObject["items"] as? [[String: Any]])
        XCTAssertEqual(10, items.count, "All 10 concurrently added logs should be in the batch")
        // Note: We can't verify exact order due to concurrency, but count should be correct
    }
    
    // MARK: - Helper Methods
    
    private func createTestLog(
        level: SentryLog.Level = .info,
        body: String = "Test log message",
        attributes: [String: SentryLog.Attribute] = [:]
    ) -> SentryLog {
        return SentryLog(
            timestamp: Date(timeIntervalSince1970: 1_627_846_801),
            level: level,
            body: body,
            attributes: attributes
        )
    }
    
    private func waitBeforeTimeout() {
        // Wait for timer to fire
        let expectation = self.expectation(description: "Wait for async add")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 0.5)
    }
    
    private func waitAfterTimeout() {
        // Wait for timer to fire
        let expectation = self.expectation(description: "Wait for timer flush")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 0.5)
    }
}
