@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

private struct TestItem: TelemetryItem {
    var attributesDict: [String: SentryAttributeContent]
    var traceId: SentryId
    var spanId: SpanId?
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

    override func setUp() {
        super.setUp()
        capturedDataInvocations = .init()
        testDateProvider = TestCurrentDateProvider()
        testDispatchQueue = TestSentryDispatchQueueWrapper()
        testDispatchQueue.dispatchAsyncExecutesBlock = true
        testTelemetryBuffer = MockTelemetryBuffer()
    }

    private func getSut(
        flushTimeout: TimeInterval = 0.1,
        maxItemCount: Int = 10,
        maxBufferSizeBytes: Int = 8_000
    ) -> DefaultTelemetryBuffer<MockTelemetryBuffer, TestItem> {
        var config = DefaultTelemetryBuffer<MockTelemetryBuffer, TestItem>.Config(
            flushTimeout: flushTimeout,
            maxItemCount: maxItemCount,
            maxBufferSizeBytes: maxBufferSizeBytes
        )
        config.capturedDataCallback = { [weak self] data, count in
            self?.capturedDataInvocations.record((data, count))
        }

        return DefaultTelemetryBuffer(
            config: config,
            buffer: testTelemetryBuffer,
            dateProvider: testDateProvider,
            dispatchQueue: testDispatchQueue,
            itemForwardingTriggers: NoOpTelemetryBufferDataForwardingTriggers()
        )
    }

    // MARK: - Add Method Tests
    
    func testAdd_whenSingleItem_shouldAppendToTelemetryBuffer() {
        // -- Arrange --
        let sut = getSut()
        let item = TestItem(body: "test item")
        
        // -- Act --
        sut.add(item)
        
        // -- Assert --
        XCTAssertEqual(testTelemetryBuffer.itemsCount, 1)
        XCTAssertEqual(testTelemetryBuffer.appendedItems.first?.body, "test item")
    }
    
    func testAdd_whenMultipleItems_shouldBatchTogether() {
        // -- Arrange --
        let sut = getSut()
        
        // -- Act --
        sut.add(TestItem(body: "Item 1"))
        sut.add(TestItem(body: "Item 2"))
        
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
        sut.add(TestItem(body: "Item 1"))
        sut.add(TestItem(body: "Item 2"))
        XCTAssertEqual(capturedDataInvocations.count, 0)
        
        sut.add(TestItem(body: "Item 3"))
        
        // -- Assert --
        XCTAssertEqual(capturedDataInvocations.count, 1)
        XCTAssertEqual(testTelemetryBuffer.flushCallCount, 1)
    }
    
    // MARK: - TelemetryBuffer Size Tests
    
    func testAdd_whenMaxTelemetryBufferSizeReached_shouldFlushImmediately() {
        // -- Arrange --
        let sut = getSut(maxBufferSizeBytes: 200) // Each item is ~100 bytes
        
        // -- Act --
        sut.add(TestItem(body: "Item 1"))
        XCTAssertEqual(capturedDataInvocations.count, 0)
        
        sut.add(TestItem(body: "Item 2")) // Total ~200 bytes
        
        // -- Assert --
        XCTAssertEqual(capturedDataInvocations.count, 1)
        XCTAssertEqual(testTelemetryBuffer.flushCallCount, 1)
    }
    
    // MARK: - Timeout Tests
    
    func testAdd_whenFirstItemAdded_shouldStartTimer() {
        // -- Arrange --
        let sut = getSut()
        
        // -- Act --
        sut.add(TestItem())
        
        // -- Assert --
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.count, 1)
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.first?.interval, 0.1)
    }
    
    func testAdd_whenTimerFires_shouldFlushAfterDelay() {
        // -- Arrange --
        let sut = getSut()
        
        // -- Act --
        sut.add(TestItem())
        testDispatchQueue.invokeLastDispatchAfterWorkItem()
        
        // -- Assert --
        XCTAssertEqual(capturedDataInvocations.count, 1)
        XCTAssertEqual(testTelemetryBuffer.flushCallCount, 1)
    }
    
    func testAdd_whenTelemetryBufferNotEmpty_shouldNotStartAdditionalTimer() {
        // -- Arrange --
        let sut = getSut()
        
        // -- Act --
        sut.add(TestItem())
        let initialTimerCount = testDispatchQueue.dispatchAfterWorkItemInvocations.count
        sut.add(TestItem())
        
        // -- Assert --
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.count, initialTimerCount)
    }
    
    // MARK: - Capture Method Tests
    
    func testCapture_whenItemsInTelemetryBuffer_shouldFlushImmediately() {
        // -- Arrange --
        let sut = getSut()
        sut.add(TestItem(body: "Item 1"))
        sut.add(TestItem(body: "Item 2"))
        
        // -- Act --
        _ = sut.capture()
        
        // -- Assert --
        XCTAssertEqual(capturedDataInvocations.count, 1)
        XCTAssertEqual(testTelemetryBuffer.flushCallCount, 1)
    }
    
    func testCapture_whenMultipleItems_shouldPassCorrectItemCount() {
        // -- Arrange --
        let sut = getSut()
        sut.add(TestItem(body: "Item 1"))
        sut.add(TestItem(body: "Item 2"))
        sut.add(TestItem(body: "Item 3"))
        
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
        sut.add(TestItem())
        let timerWorkItem = testDispatchQueue.dispatchAfterWorkItemInvocations.first?.workItem
        
        // -- Act --
        _ = sut.capture()
        timerWorkItem?.perform()
        
        // -- Assert --
        XCTAssertEqual(capturedDataInvocations.count, 1, "Timer should be cancelled")
    }
    
    // MARK: - Edge Cases Tests
    
    func testAdd_whenScheduledFlushAfterManualFlush_shouldNotFlushAgain() {
        // -- Arrange --
        let sut = getSut(maxBufferSizeBytes: 200)
        sut.add(TestItem())
        let timerWorkItem = testDispatchQueue.dispatchAfterWorkItemInvocations.first?.workItem
        
        // -- Act --
        sut.add(TestItem()) // Triggers immediate flush
        timerWorkItem?.perform() // Try to flush again
        
        // -- Assert --
        XCTAssertEqual(capturedDataInvocations.count, 1)
        XCTAssertEqual(testTelemetryBuffer.flushCallCount, 1)
    }
    
    func testAdd_whenAfterFlush_shouldStartNewBatch() {
        // -- Arrange --
        let sut = getSut()
        
        // -- Act --
        sut.add(TestItem(body: "Item 1"))
        _ = sut.capture()
        sut.add(TestItem(body: "Item 2"))
        _ = sut.capture()
        
        // -- Assert --
        XCTAssertEqual(capturedDataInvocations.count, 2)
        XCTAssertEqual(testTelemetryBuffer.flushCallCount, 2)
    }

    // MARK: - Item Forwarding Tests

    func testItemForwardingDelegate_whenInvoked_capturesItems() {
        // -- Arrange --
        let mockItemForwarding = MockTelemetryBufferDataForwardingTriggers()
        var config = DefaultTelemetryBuffer<MockTelemetryBuffer, TestItem>.Config(
            flushTimeout: 0.1,
            maxItemCount: 10,
            maxBufferSizeBytes: 8_000
        )
        config.capturedDataCallback = { [weak self] data, count in
            self?.capturedDataInvocations.record((data, count))
        }

        let sut = DefaultTelemetryBuffer(
            config: config,
            buffer: testTelemetryBuffer,
            dateProvider: testDateProvider,
            dispatchQueue: testDispatchQueue,
            itemForwardingTriggers: mockItemForwarding
        )

        sut.add(TestItem(body: "Item 1"))
        sut.add(TestItem(body: "Item 2"))

        // -- Act --
        mockItemForwarding.invokeDelegate()

        // -- Assert --
        XCTAssertEqual(capturedDataInvocations.count, 1)
        XCTAssertEqual(testTelemetryBuffer.flushCallCount, 1)
    }

    func testItemForwardingDelegate_usesWeakReference_avoidsRetainCycle() {
        // -- Arrange --
        let mockItemForwarding = MockTelemetryBufferDataForwardingTriggers()

        func createBuffer() -> DefaultTelemetryBuffer<MockTelemetryBuffer, TestItem>? {
            var config = DefaultTelemetryBuffer<MockTelemetryBuffer, TestItem>.Config(
                flushTimeout: 0.1,
                maxItemCount: 10,
                maxBufferSizeBytes: 8_000
            )
            config.capturedDataCallback = { [weak self] data, count in
                self?.capturedDataInvocations.record((data, count))
            }

            let sut = DefaultTelemetryBuffer(
                config: config,
                buffer: testTelemetryBuffer,
                dateProvider: testDateProvider,
                dispatchQueue: testDispatchQueue,
                itemForwardingTriggers: mockItemForwarding
            )

            XCTAssertNotNil(sut)
            return sut
        }

        weak var weakSut: DefaultTelemetryBuffer<MockTelemetryBuffer, TestItem>?

        // -- Act --
        weakSut = createBuffer()

        // -- Assert --
        XCTAssertNil(weakSut, "Buffer should be deallocated after leaving function scope, proving no retain cycle")
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
