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
        sut = SentryLogBatcher(
            client: testClient,
            flushTimeout: 5.0,
            maxBufferSize: 3,
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
        let sentData = try XCTUnwrap(testClient.captureLogsDataInvocations.first)
        let jsonObject = try XCTUnwrap(JSONSerialization.jsonObject(with: sentData) as? [String: Any])
        let items = try XCTUnwrap(jsonObject["items"] as? [[String: Any]])
        XCTAssertEqual(2, items.count)
    }
    
    // MARK: - Buffer Size Tests
    
    func testBufferReachesMaxSize_FlushesImmediately() throws {
        // Given
        let log1 = createTestLog(body: "Log 1")
        let log2 = createTestLog(body: "Log 2")
        let log3 = createTestLog(body: "Log 3")
        
        // When - add logs up to max buffer size (3)
        sut.add(log1)
        sut.add(log2)
        XCTAssertEqual(testClient.captureLogsDataInvocations.count, 0)
        
        sut.add(log3) // This should trigger immediate flush
        
        // Then
        XCTAssertEqual(testClient.captureLogsDataInvocations.count, 1)
        
        // Verify all three logs are batched together
        let sentData = try XCTUnwrap(testClient.captureLogsDataInvocations.first)
        let jsonObject = try XCTUnwrap(JSONSerialization.jsonObject(with: sentData) as? [String: Any])
        let items = try XCTUnwrap(jsonObject["items"] as? [[String: Any]])
        XCTAssertEqual(3, items.count)
    }
    
    // MARK: - Timeout Tests
    
    func testTimeout_FlushesAfterDelay() throws {
        // Given
        let log = createTestLog()
        
        // When
        sut.add(log)
        
        // Then - no immediate flush
        XCTAssertEqual(testClient.captureLogsDataInvocations.count, 0)
        
        // Called dispatch with correct interval
        let invocation = try XCTUnwrap(testDispatchQueue.dispatchAfterInvocations.first)
        XCTAssertEqual(invocation.interval, 5.0)
        
        // Simulate timeout by executing the scheduled block
        let scheduledBlock = invocation.block
        scheduledBlock()
        
        // Verify flush occurred
        XCTAssertEqual(testClient.captureLogsDataInvocations.count, 1)
    }
    
    func testMultipleLogsBeforeTimeout_CancelsAndReschedulesFlush() throws {
        // Given
        let log1 = createTestLog(body: "Log 1")
        let log2 = createTestLog(body: "Log 2")
        
        // When
        sut.add(log1)
        XCTAssertEqual(testDispatchQueue.dispatchAfterInvocations.count, 1)
        
        sut.add(log2)
        XCTAssertEqual(testDispatchQueue.dispatchAfterInvocations.count, 2)
        
        // Execute the first scheduled flush (should do nothing due to cancellation)
        let firstBlock = testDispatchQueue.dispatchAfterInvocations.invocations[0].block
        firstBlock()
        XCTAssertEqual(testClient.captureLogsDataInvocations.count, 0, "First flush should be cancelled")
        
        // Execute second scheduled flush
        let secondBlock = testDispatchQueue.dispatchAfterInvocations.invocations[1].block
        secondBlock()
        
        // Verify both logs are flushed together
        XCTAssertEqual(testClient.captureLogsDataInvocations.count, 1)
        let sentData = try XCTUnwrap(testClient.captureLogsDataInvocations.first)
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
        
        let sentData = try XCTUnwrap(testClient.captureLogsDataInvocations.first)
        let jsonObject = try XCTUnwrap(JSONSerialization.jsonObject(with: sentData) as? [String: Any])
        let items = try XCTUnwrap(jsonObject["items"] as? [[String: Any]])
        XCTAssertEqual(2, items.count)
    }
    
    func testManualFlush_CancelsScheduledFlush() throws {
        // Given
        let log = createTestLog()
        
        // When
        sut.add(log)
        XCTAssertEqual(testDispatchQueue.dispatchAfterInvocations.count, 1)
        
        sut.flush()
        XCTAssertEqual(testClient.captureLogsDataInvocations.count, 1, "Manual flush should work")
        
        // Execute the scheduled flush (should do nothing since buffer was already flushed)
        let scheduledBlock = try XCTUnwrap(testDispatchQueue.dispatchAfterInvocations.invocations.first).block
        scheduledBlock()
        
        // Then - no additional flush should occur (proves cancellation worked)
        XCTAssertEqual(testClient.captureLogsDataInvocations.count, 1, "Scheduled flush should be cancelled")
    }
    
    func testFlushEmptyBuffer_DoesNothing() {
        // When
        sut.flush()
        
        // Then
        XCTAssertEqual(testClient.captureLogsDataInvocations.count, 0)
    }
    
    // MARK: - Edge Cases Tests
    
    func testScheduledFlushAfterBufferAlreadyFlushed_DoesNothing() throws {
        // Given
        let log1 = createTestLog(body: "Log 1")
        let log2 = createTestLog(body: "Log 2")
        let log3 = createTestLog(body: "Log 3")
        
        // When - fill buffer to trigger immediate flush
        sut.add(log1)
        sut.add(log2)
        sut.add(log3)
        
        XCTAssertEqual(testClient.captureLogsDataInvocations.count, 1)
        
        // Simulate a delayed flush callback (should do nothing since buffer is empty)
        if let delayedBlock = testDispatchQueue.dispatchAfterInvocations.first?.block {
            delayedBlock()
        }
        
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
        for (index, data) in testClient.captureLogsDataInvocations.invocations.enumerated() {
            let jsonObject = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
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
            maxBufferSize: 100, // Large buffer to avoid immediate flushes
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
        
        wait(for: [expectation], timeout: 5.0)
        
        // Then - manually flush and verify all logs were added
        sutWithRealQueue.flush()
        
        XCTAssertEqual(testClient.captureLogsDataInvocations.count, 1)
        
        // Verify all 10 logs were included in the single batch
        let sentData = try XCTUnwrap(testClient.captureLogsDataInvocations.first)
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
}
