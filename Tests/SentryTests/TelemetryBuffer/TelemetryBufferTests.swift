@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

private struct TestScope: TelemetryBufferScope {
    var replayId: String?
    var propagationContextTraceId: SentryId
    var span: Span?
    var userObject: User?
    var contextStore: [String: [String: Any]] = [:]
    var attributes: [String: Any] = [:]
    
    init(propagationContextTraceId: SentryId = SentryId()) {
        self.propagationContextTraceId = propagationContextTraceId
    }

    func getContextForKey(_ key: String) -> [String: Any]? {
        return contextStore[key]
    }
}

private struct TestItem: TelemetryBufferItem {
    var attributesDict: [String: SentryAttributeContent]
    var traceId: SentryId
    var body: String

    init(body: String = "test", attributes: [String: SentryAttributeContent] = [:]) {
        self.body = body
        self.attributesDict = attributes
        self.traceId = SentryId.empty
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(body)
    }
}

// Note: MockTelemetryBuffer must be a class (not struct) because TelemetryBuffer stores it internally
// and we need to observe changes from the test. Using a struct would create a copy.
private class MockTelemetryBuffer: InternalTelemetryBuffer {
    typealias Item = TestItem

    var appendedItems: [TestItem] = []
    var flushCallCount = 0
    var mockSize: Int = 0

    func append(_ element: Item) throws {
        appendedItems.append(element)
        // Simulate size growth - each item adds ~100 bytes
        mockSize += 100
    }

    func clear() {
        appendedItems.removeAll()
        mockSize = 0
        flushCallCount += 1
    }

    var itemsCount: Int {
        appendedItems.count
    }

    var itemsDataSize: Int {
        mockSize
    }

    var batchedData: Data {
        // Return minimal data for testing - we don't need to decode it
        Data("test".utf8)
    }
}

final class TelemetryBufferTests: XCTestCase {
    private var capturedDataInvocations: Invocations<(data: Data, count: Int)>!
    private var testTelemetryBuffer: MockTelemetryBuffer!
    private var testDateProvider: TestCurrentDateProvider!
    private var testDispatchQueue: TestSentryDispatchQueueWrapper!
    private var testScope: TestScope!

    override func setUp() {
        super.setUp()
        capturedDataInvocations = .init()
        testDateProvider = TestCurrentDateProvider()
        testDispatchQueue = TestSentryDispatchQueueWrapper()
        testDispatchQueue.dispatchAsyncExecutesBlock = true
        testTelemetryBuffer = MockTelemetryBuffer()
        testScope = TestScope()
    }

    private func getSut(
        sendDefaultPii: Bool = false,
        flushTimeout: TimeInterval = 0.1,
        maxItemCount: Int = 10,
        maxBufferSizeBytes: Int = 8_000,
        beforeSendItem: ((TestItem) -> TestItem?)? = nil
    ) -> TelemetryBuffer<MockTelemetryBuffer, TestItem, TestScope> {
        var config = TelemetryBuffer<MockTelemetryBuffer, TestItem, TestScope>.Config(
            sendDefaultPii: sendDefaultPii,
            flushTimeout: flushTimeout,
            maxItemCount: maxItemCount,
            maxBufferSizeBytes: maxBufferSizeBytes,
            beforeSendItem: beforeSendItem
        )
        let metadata = TelemetryBuffer<MockTelemetryBuffer, TestItem, TestScope>.Metadata(
            environment: "test",
            releaseName: "test-release",
            installationId: "test-installation-id"
        )
        config.capturedDataCallback = { [weak self] data, count in
            self?.capturedDataInvocations.record((data, count))
        }
        
        return TelemetryBuffer(
            config: config,
            metadata: metadata,
            buffer: testTelemetryBuffer,
            dateProvider: testDateProvider,
            dispatchQueue: testDispatchQueue
        )
    }

    // MARK: - Add Method Tests
    
    func testAdd_whenSingleItem_shouldAppendToTelemetryBuffer() {
        // -- Arrange --
        let sut = getSut()
        let item = TestItem(body: "test item")
        
        // -- Act --
        sut.add(item, scope: testScope)
        
        // -- Assert --
        XCTAssertEqual(testTelemetryBuffer.itemsCount, 1)
        XCTAssertEqual(testTelemetryBuffer.appendedItems.first?.body, "test item")
    }
    
    func testAdd_whenMultipleItems_shouldBatchTogether() {
        // -- Arrange --
        let sut = getSut()
        
        // -- Act --
        sut.add(TestItem(body: "Item 1"), scope: testScope)
        sut.add(TestItem(body: "Item 2"), scope: testScope)
        
        // -- Assert --
        XCTAssertEqual(testTelemetryBuffer.itemsCount, 2)
        XCTAssertEqual(testTelemetryBuffer.appendedItems[0].body, "Item 1")
        XCTAssertEqual(testTelemetryBuffer.appendedItems[1].body, "Item 2")
    }
    
    // MARK: - Max Item Count Tests
    
    func testAdd_whenMaxItemCountReached_shouldFlushImmediately() {
        // -- Arrange --
        let sut = getSut(maxItemCount: 3)
        
        // -- Act --
        sut.add(TestItem(body: "Item 1"), scope: testScope)
        sut.add(TestItem(body: "Item 2"), scope: testScope)
        XCTAssertEqual(capturedDataInvocations.count, 0)
        
        sut.add(TestItem(body: "Item 3"), scope: testScope)
        
        // -- Assert --
        XCTAssertEqual(capturedDataInvocations.count, 1)
        XCTAssertEqual(testTelemetryBuffer.flushCallCount, 1)
    }
    
    // MARK: - TelemetryBuffer Size Tests
    
    func testAdd_whenMaxTelemetryBufferSizeReached_shouldFlushImmediately() {
        // -- Arrange --
        let sut = getSut(maxBufferSizeBytes: 200) // Each item is ~100 bytes
        
        // -- Act --
        sut.add(TestItem(body: "Item 1"), scope: testScope)
        XCTAssertEqual(capturedDataInvocations.count, 0)
        
        sut.add(TestItem(body: "Item 2"), scope: testScope) // Total ~200 bytes
        
        // -- Assert --
        XCTAssertEqual(capturedDataInvocations.count, 1)
        XCTAssertEqual(testTelemetryBuffer.flushCallCount, 1)
    }
    
    // MARK: - Timeout Tests
    
    func testAdd_whenFirstItemAdded_shouldStartTimer() {
        // -- Arrange --
        let sut = getSut()
        
        // -- Act --
        sut.add(TestItem(), scope: testScope)
        
        // -- Assert --
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.count, 1)
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.first?.interval, 0.1)
    }
    
    func testAdd_whenTimerFires_shouldFlushAfterDelay() {
        // -- Arrange --
        let sut = getSut()
        
        // -- Act --
        sut.add(TestItem(), scope: testScope)
        testDispatchQueue.invokeLastDispatchAfterWorkItem()
        
        // -- Assert --
        XCTAssertEqual(capturedDataInvocations.count, 1)
        XCTAssertEqual(testTelemetryBuffer.flushCallCount, 1)
    }
    
    func testAdd_whenTelemetryBufferNotEmpty_shouldNotStartAdditionalTimer() {
        // -- Arrange --
        let sut = getSut()
        
        // -- Act --
        sut.add(TestItem(), scope: testScope)
        let initialTimerCount = testDispatchQueue.dispatchAfterWorkItemInvocations.count
        sut.add(TestItem(), scope: testScope)
        
        // -- Assert --
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.count, initialTimerCount)
    }
    
    // MARK: - Capture Method Tests
    
    func testCapture_whenItemsInTelemetryBuffer_shouldFlushImmediately() {
        // -- Arrange --
        let sut = getSut()
        sut.add(TestItem(body: "Item 1"), scope: testScope)
        sut.add(TestItem(body: "Item 2"), scope: testScope)
        
        // -- Act --
        _ = sut.capture()
        
        // -- Assert --
        XCTAssertEqual(capturedDataInvocations.count, 1)
        XCTAssertEqual(testTelemetryBuffer.flushCallCount, 1)
    }
    
    func testCapture_whenMultipleItems_shouldPassCorrectItemCount() {
        // -- Arrange --
        let sut = getSut()
        sut.add(TestItem(body: "Item 1"), scope: testScope)
        sut.add(TestItem(body: "Item 2"), scope: testScope)
        sut.add(TestItem(body: "Item 3"), scope: testScope)
        
        // -- Act --
        _ = sut.capture()
        
        // -- Assert --
        XCTAssertEqual(capturedDataInvocations.count, 1)
        let invocation = capturedDataInvocations.invocations.first!
        XCTAssertEqual(invocation.1, 3, "Callback should receive item count, not byte size")
    }
    
    func testCapture_whenEmptyTelemetryBuffer_shouldNotCallCallback() {
        // -- Arrange --
        let sut = getSut()
        
        // -- Act --
        _ = sut.capture()
        
        // -- Assert --
        // Note: flush() is always called (in defer block), but callback should not be called when empty
        XCTAssertEqual(capturedDataInvocations.count, 0)
    }
    
    func testCapture_whenTimerScheduled_shouldCancelTimer() {
        // -- Arrange --
        let sut = getSut()
        sut.add(TestItem(), scope: testScope)
        let timerWorkItem = testDispatchQueue.dispatchAfterWorkItemInvocations.first?.workItem
        
        // -- Act --
        _ = sut.capture()
        timerWorkItem?.perform()
        
        // -- Assert --
        XCTAssertEqual(capturedDataInvocations.count, 1, "Timer should be cancelled")
    }
    
    // MARK: - BeforeSendItem Callback Tests
    
    func testAdd_whenBeforeSendItemModifiesItem_shouldAppendModifiedItem() {
        // -- Arrange --
        var beforeSendCalled = false
        let sut = getSut(
            beforeSendItem: { item in
                beforeSendCalled = true
                var modified = item
                modified.body = "Modified"
                return modified
            }
        )
        
        // -- Act --
        sut.add(TestItem(body: "Original"), scope: testScope)
        // Check before capture since capture flushes the buffer
        XCTAssertEqual(testTelemetryBuffer.appendedItems.first?.body, "Modified")
        _ = sut.capture()
        
        // -- Assert --
        XCTAssertTrue(beforeSendCalled)
        XCTAssertEqual(capturedDataInvocations.count, 1)
    }
    
    func testAdd_whenBeforeSendItemReturnsNil_shouldDropItem() {
        // -- Arrange --
        let sut = getSut(beforeSendItem: { _ in nil })
        
        // -- Act --
        sut.add(TestItem(), scope: testScope)
        _ = sut.capture()
        
        // -- Assert --
        XCTAssertEqual(capturedDataInvocations.count, 0)
        XCTAssertEqual(testTelemetryBuffer.itemsCount, 0)
    }
    
    // MARK: - Edge Cases Tests
    
    func testAdd_whenScheduledFlushAfterManualFlush_shouldNotFlushAgain() {
        // -- Arrange --
        let sut = getSut(maxBufferSizeBytes: 200)
        sut.add(TestItem(), scope: testScope)
        let timerWorkItem = testDispatchQueue.dispatchAfterWorkItemInvocations.first?.workItem
        
        // -- Act --
        sut.add(TestItem(), scope: testScope) // Triggers immediate flush
        timerWorkItem?.perform() // Try to flush again
        
        // -- Assert --
        XCTAssertEqual(capturedDataInvocations.count, 1)
        XCTAssertEqual(testTelemetryBuffer.flushCallCount, 1)
    }
    
    func testAdd_whenAfterFlush_shouldStartNewBatch() {
        // -- Arrange --
        let sut = getSut()
        
        // -- Act --
        sut.add(TestItem(body: "Item 1"), scope: testScope)
        _ = sut.capture()
        sut.add(TestItem(body: "Item 2"), scope: testScope)
        _ = sut.capture()
        
        // -- Assert --
        XCTAssertEqual(capturedDataInvocations.count, 2)
        XCTAssertEqual(testTelemetryBuffer.flushCallCount, 2)
    }
}
