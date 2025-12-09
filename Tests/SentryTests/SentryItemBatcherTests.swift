@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

final class SentryItemBatcherTests: XCTestCase {
    
    private var options: Options!
    private var testDelegate: TestItemBatcherDelegate!
    private var testDispatchQueue: TestSentryDispatchQueueWrapper!
    private var scope: Scope!

    private func getSut() -> SentryItemBatcher<TestItem> {
        let sut = SentryItemBatcher<TestItem>(
            config: .init(
                beforeSendItem: nil,
                environment: options.environment,
                releaseName: options.releaseName,
                flushTimeout: 0.1, // Very small timeout for testing
                maxItemCount: 10, // Maximum 10 items per batch
                maxBufferSizeBytes: 8_000, // byte limit for testing (item with attributes ~390 bytes)
                getInstallationId: { [options] in
                    SentryInstallation.cachedId(withCacheDirectoryPath: options.cacheDirectoryPath)
                }
            ),
            dispatchQueue: testDispatchQueue
        )
        sut.delegate = testDelegate
        return sut
    }

    override func setUp() {
        super.setUp()
        
        options = Options()
        options.dsn = TestConstants.dsnForTestCase(type: Self.self)
        options.environment = "test-environment"
        
        testDelegate = TestItemBatcherDelegate()
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
    
    func testAddMultipleItems_BatchesTogether() throws {
        // -- Arrange --
        let sut = getSut()
        let item1 = createTestItem(body: "Item 1")
        let item2 = createTestItem(body: "Item 2")
        
        // -- Act --
        sut.addItem(item1, scope: scope)
        sut.addItem(item2, scope: scope)
        sut.captureItems()
        
        // -- Assert --
        XCTAssertEqual(testDelegate.captureItemsBatcherDataInvocations.count, 1)
        
        let capturedItems = testDelegate.getCapturedItems()
        XCTAssertEqual(capturedItems.count, 2)
        XCTAssertEqual(capturedItems[0].body, "Item 1")
        XCTAssertEqual(capturedItems[1].body, "Item 2")
    }
    
    // MARK: - Buffer Size Tests
    
    func testBufferReachesMaxSize_FlushesImmediately() throws {
        // -- Arrange --
        let sut = getSut()
        let largeItemBody = String(repeating: "A", count: 8_000) // Larger than 8000 byte limit
        let largeItem = createTestItem(body: largeItemBody)
        
        // -- Act --
        sut.addItem(largeItem, scope: scope)

        // -- Assert --
        XCTAssertEqual(testDelegate.captureItemsBatcherDataInvocations.count, 1)
        
        // Verify the large item is sent
        let capturedItems = testDelegate.getCapturedItems()
        XCTAssertEqual(capturedItems.count, 1)
        XCTAssertEqual(capturedItems[0].body, largeItemBody)
    }
    
    // MARK: - Max Item Count Tests
    
    func testMaxItemCount_FlushesWhenReached() throws {
        // -- Arrange --
        let sut = getSut()

        // -- Act --
        for i in 0..<9 {
            let item = createTestItem(body: "Item \(i + 1)")
            sut.addItem(item, scope: scope)
        }
        
        XCTAssertEqual(testDelegate.captureItemsBatcherDataInvocations.count, 0)
        
        let item = createTestItem(body: "Item \(10)") // Reached 10 max items limit
        sut.addItem(item, scope: scope)
        
        // -- Assert --
        XCTAssertEqual(testDelegate.captureItemsBatcherDataInvocations.count, 1)
        
        let capturedItems = testDelegate.getCapturedItems()
        XCTAssertEqual(capturedItems.count, 10, "Should have captured exactly \(10) items")
    }
    
    // MARK: - Timeout Tests
    
    func testTimeout_FlushesAfterDelay() throws {
        // -- Arrange --
        let sut = getSut()
        let item = createTestItem()

        // -- Act --
        sut.addItem(item, scope: scope)
        testDispatchQueue.invokeLastDispatchAfterWorkItem()
        
        // -- Assert --
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.count, 1)
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.first?.interval, 0.1)
        XCTAssertEqual(testDelegate.captureItemsBatcherDataInvocations.count, 1)
        
        let capturedItems = testDelegate.getCapturedItems()
        XCTAssertEqual(capturedItems.count, 1)
    }
    
    func testAddingItemToEmptyBuffer_StartsTimer() throws {
        // -- Arrange --
        let sut = getSut()
        let item1 = createTestItem(body: "Item 1")
        let item2 = createTestItem(body: "Item 2")
        
        // -- Act --
        sut.addItem(item1, scope: scope)
        sut.addItem(item2, scope: scope)
        testDispatchQueue.invokeLastDispatchAfterWorkItem()
        
        // -- Assert --
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.count, 1)
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.first?.interval, 0.1)
        XCTAssertEqual(testDelegate.captureItemsBatcherDataInvocations.count, 1)
        
        let capturedItems = testDelegate.getCapturedItems()
        XCTAssertEqual(capturedItems.count, 2)
    }
    
    // MARK: - Manual Capture Items Tests
    
    func testManualCaptureItems_CapturesImmediately() throws {
        // -- Arrange --
        let sut = getSut()
        let item1 = createTestItem(body: "Item 1")
        let item2 = createTestItem(body: "Item 2")
        
        // -- Act --
        sut.addItem(item1, scope: scope)
        sut.addItem(item2, scope: scope)
        sut.captureItems()
        
        // -- Assert --
        XCTAssertEqual(testDelegate.captureItemsBatcherDataInvocations.count, 1)
        
        let capturedItems = testDelegate.getCapturedItems()
        XCTAssertEqual(capturedItems.count, 2)
    }
    
    func testManualCaptureItems_CancelsScheduledCapture() throws {
        // -- Arrange --
        let sut = getSut()
        let item = createTestItem()
        sut.addItem(item, scope: scope)
        let timerWorkItem = try XCTUnwrap(testDispatchQueue.dispatchAfterWorkItemInvocations.first?.workItem)
        
        // -- Act --
        sut.captureItems()
        timerWorkItem.perform()
        
        // -- Assert --
        XCTAssertEqual(testDelegate.captureItemsBatcherDataInvocations.count, 1, "Manual flush should work and timer should be cancelled")
    }
    
    func testManualCaptureItems_WithEmptyBuffer_DoesNothing() {
        // -- Arrange --
        let sut = getSut()

        // -- Act --
        sut.captureItems()
        
        // -- Assert --
        XCTAssertEqual(testDelegate.captureItemsBatcherDataInvocations.count, 0)
    }
    
    // MARK: - Edge Cases Tests
    
    func testScheduledFlushAfterBufferAlreadyFlushed_DoesNothing() throws {
        // -- Arrange --
        let sut = getSut()
        let largeItemBody = String(repeating: "B", count: 4_000)
        let item1 = createTestItem(body: largeItemBody)
        let item2 = createTestItem(body: largeItemBody)
        
        // -- Act --
        sut.addItem(item1, scope: scope)
        let timerWorkItem = try XCTUnwrap(testDispatchQueue.dispatchAfterWorkItemInvocations.first?.workItem)
        sut.addItem(item2, scope: scope)
        timerWorkItem.perform()
        
        // -- Assert --
        XCTAssertEqual(testDelegate.captureItemsBatcherDataInvocations.count, 1)
    }
    
    func testAddItemAfterFlush_StartsNewBatch() throws {
        // -- Arrange --
        let sut = getSut()
        let item1 = createTestItem(body: "Item 1")
        let item2 = createTestItem(body: "Item 2")
        
        // -- Act --
        sut.addItem(item1, scope: scope)
        sut.captureItems()
        sut.addItem(item2, scope: scope)
        sut.captureItems()
        
        // -- Assert --
        XCTAssertEqual(testDelegate.captureItemsBatcherDataInvocations.count, 2)
        
        let allCapturedItems = testDelegate.getCapturedItems()
        XCTAssertEqual(allCapturedItems.count, 2)
        XCTAssertEqual(allCapturedItems[0].body, "Item 1")
        XCTAssertEqual(allCapturedItems[1].body, "Item 2")
    }
    
    // MARK: - Integration Tests
    
    func testConcurrentAdds_ThreadSafe() throws {
        // -- Arrange --
        let sutWithRealQueue = SentryItemBatcher<TestItem>(
            config: .init(
                beforeSendItem: nil,
                environment: options.environment,
                releaseName: options.releaseName,
                flushTimeout: 5,
                maxItemCount: 1_000, // Maximum 1000 items per batch
                maxBufferSizeBytes: 10_000,
                getInstallationId: { [options] in
                    SentryInstallation.cachedId(withCacheDirectoryPath: options.cacheDirectoryPath)
                }
            ),
            dispatchQueue: SentryDispatchQueueWrapper()
        )
        sutWithRealQueue.delegate = testDelegate
        
        let expectation = XCTestExpectation(description: "Concurrent adds")
        expectation.expectedFulfillmentCount = 10
        
        // -- Act --
        for i in 0..<10 {
            DispatchQueue.global().async {
                let item = self.createTestItem(body: "Item \(i)")
                sutWithRealQueue.addItem(item, scope: self.scope)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 1.0)
        sutWithRealQueue.captureItems()
        
        // -- Assert --
        let capturedItems = self.testDelegate.getCapturedItems()
        XCTAssertEqual(capturedItems.count, 10, "All 10 concurrently added items should be in the batch")
    }

    func testDispatchAfterTimeoutWithRealDispatchQueue() throws {
        // -- Arrange --
        let sutWithRealQueue = SentryItemBatcher<TestItem>(
            config: .init(
                beforeSendItem: nil,
                environment: options.environment,
                releaseName: options.releaseName,
                flushTimeout: 0.2,
                maxItemCount: 1_000, // Maximum 1000 items per batch
                maxBufferSizeBytes: 10_000,
                getInstallationId: { [options] in
                    SentryInstallation.cachedId(withCacheDirectoryPath: options.cacheDirectoryPath)
                }
            ),
            dispatchQueue: SentryDispatchQueueWrapper()
        )
        sutWithRealQueue.delegate = testDelegate
        
        let item = createTestItem(body: "Real timeout test item")
        let expectation = XCTestExpectation(description: "Real timeout flush")
        
        // -- Act --
        sutWithRealQueue.addItem(item, scope: scope)
        XCTAssertEqual(testDelegate.captureItemsBatcherDataInvocations.count, 0)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // -- Assert --
        XCTAssertEqual(testDelegate.captureItemsBatcherDataInvocations.count, 1, "Timeout should trigger flush")
        
        let capturedItems = self.testDelegate.getCapturedItems()
        XCTAssertEqual(capturedItems.count, 1, "Should contain exactly one item")
        XCTAssertEqual(capturedItems[0].body, "Real timeout test item")
    }
    
    // MARK: - Attribute Enrichment Tests
    
    func testAddItem_AddsDefaultAttributes() throws {
        // -- Arrange --
        options.releaseName = "1.0.0"
        let sut = getSut()
        let span = SentryTracer(transactionContext: TransactionContext(name: "Test Transaction", operation: "test-operation"), hub: nil)
        scope.span = span
        let item = createTestItem(body: "Test item message")
        
        // -- Act --
        sut.addItem(item, scope: scope)
        sut.captureItems()
        
        // -- Assert --
        let capturedItems = testDelegate.getCapturedItems()
        XCTAssertEqual(capturedItems.count, 1)
        
        let capturedItem = try XCTUnwrap(capturedItems.first)
        let attributes = capturedItem.attributes
        
        XCTAssertEqual(attributes["sentry.sdk.name"]?.value as? String, SentryMeta.sdkName)
        XCTAssertEqual(attributes["sentry.sdk.version"]?.value as? String, SentryMeta.versionString)
        XCTAssertEqual(attributes["sentry.environment"]?.value as? String, "test-environment")
        XCTAssertEqual(attributes["sentry.release"]?.value as? String, "1.0.0")
        XCTAssertEqual(attributes["sentry.trace.parent_span_id"]?.value as? String, span.spanId.sentrySpanIdString)
    }
    
    func testAddItem_DoesNotAddNilDefaultAttributes() throws {
        // -- Arrange --
        options.releaseName = nil
        let sut = getSut()
        let item = createTestItem(body: "Test item message")
        
        // -- Act --
        sut.addItem(item, scope: scope)
        sut.captureItems()
        
        // -- Assert --
        let capturedItems = testDelegate.getCapturedItems()
        let capturedItem = try XCTUnwrap(capturedItems.first)
        let attributes = capturedItem.attributes
        
        XCTAssertNil(attributes["sentry.release"])
        XCTAssertNil(attributes["sentry.trace.parent_span_id"])
        XCTAssertEqual(attributes["sentry.sdk.name"]?.value as? String, SentryMeta.sdkName)
        XCTAssertEqual(attributes["sentry.sdk.version"]?.value as? String, SentryMeta.versionString)
        XCTAssertEqual(attributes["sentry.environment"]?.value as? String, "test-environment")
    }
    
    func testAddItem_SetsTraceIdFromPropagationContext() throws {
        // -- Arrange --
        let expectedTraceId = SentryId()
        let propagationContext = SentryPropagationContext(trace: expectedTraceId, spanId: SpanId())
        scope.propagationContext = propagationContext
        let sut = getSut()
        let item = createTestItem(body: "Test item message with trace ID")
        
        // -- Act --
        sut.addItem(item, scope: scope)
        sut.captureItems()
        
        // -- Assert --
        let capturedItems = testDelegate.getCapturedItems()
        let capturedItem = try XCTUnwrap(capturedItems.first)
        XCTAssertEqual(capturedItem.traceId, expectedTraceId)
    }
    
    func testAddItem_AddsUserAttributes() throws {
        // -- Arrange --
        let user = User()
        user.userId = "123"
        user.email = "test@test.com"
        user.name = "test-name"
        scope.setUser(user)
        let sut = getSut()
        let item = createTestItem(body: "Test item message with user")
        
        // -- Act --
        sut.addItem(item, scope: scope)
        sut.captureItems()
        
        // -- Assert --
        let capturedItems = testDelegate.getCapturedItems()
        let capturedItem = try XCTUnwrap(capturedItems.first)
        let attributes = capturedItem.attributes
        
        XCTAssertEqual(attributes["user.id"]?.value as? String, "123")
        XCTAssertEqual(attributes["user.name"]?.value as? String, "test-name")
        XCTAssertEqual(attributes["user.email"]?.value as? String, "test@test.com")
    }
    
    func testAddItem_DoesNotAddNilUserAttributes() throws {
        // -- Arrange --
        let user = User()
        user.userId = "123"
        scope.setUser(user)
        let sut = getSut()
        let item = createTestItem(body: "Test item message with partial user")
        
        // -- Act --
        sut.addItem(item, scope: scope)
        sut.captureItems()
        
        // -- Assert --
        let capturedItems = testDelegate.getCapturedItems()
        let capturedItem = try XCTUnwrap(capturedItems.first)
        let attributes = capturedItem.attributes
        
        XCTAssertEqual(attributes["user.id"]?.value as? String, "123")
        XCTAssertNil(attributes["user.name"])
        XCTAssertNil(attributes["user.email"])
    }
    
    func testAddItem_NoUserAttributesAreSetIfInstallationIdIsNotCached() throws {
        // -- Arrange --
        let sut = getSut()
        let item = createTestItem(body: "Test item message without user")
        
        // -- Act --
        sut.addItem(item, scope: scope)
        sut.captureItems()
        
        // -- Assert --
        let capturedItems = testDelegate.getCapturedItems()
        let capturedItem = try XCTUnwrap(capturedItems.first)
        let attributes = capturedItem.attributes
        
        XCTAssertNil(attributes["user.id"])
        XCTAssertNil(attributes["user.name"])
        XCTAssertNil(attributes["user.email"])
    }
    
    func testAddItem_OnlySetsUserIdToInstallationIdWhenNoUserIsSet() throws {
        // -- Arrange --
        _ = SentryInstallation.id(withCacheDirectoryPath: options.cacheDirectoryPath)
        let sut = getSut()
        let item = createTestItem(body: "Test item message without user")
        
        // -- Act --
        sut.addItem(item, scope: scope)
        sut.captureItems()
        
        // -- Assert --
        let capturedItems = testDelegate.getCapturedItems()
        let capturedItem = try XCTUnwrap(capturedItems.first)
        let attributes = capturedItem.attributes
        
        XCTAssertNotNil(attributes["user.id"])
        XCTAssertEqual(attributes["user.id"]?.value as? String, SentryInstallation.id(withCacheDirectoryPath: options.cacheDirectoryPath))
        XCTAssertNil(attributes["user.name"])
        XCTAssertNil(attributes["user.email"])
    }
    
    func testAddItem_AddsOSAndDeviceAttributes() throws {
        // -- Arrange --
        let osContext = ["name": "iOS", "version": "16.0.1"]
        let deviceContext = ["family": "iOS", "model": "iPhone14,4"]
        scope.setContext(value: osContext, key: "os")
        scope.setContext(value: deviceContext, key: "device")
        let sut = getSut()
        let item = createTestItem(body: "Test item message")
        
        // -- Act --
        sut.addItem(item, scope: scope)
        sut.captureItems()
        
        // -- Assert --
        let capturedItems = testDelegate.getCapturedItems()
        let capturedItem = try XCTUnwrap(capturedItems.first)
        let attributes = capturedItem.attributes
        
        XCTAssertEqual(attributes["os.name"]?.value as? String, "iOS")
        XCTAssertEqual(attributes["os.version"]?.value as? String, "16.0.1")
        XCTAssertEqual(attributes["device.brand"]?.value as? String, "Apple")
        XCTAssertEqual(attributes["device.model"]?.value as? String, "iPhone14,4")
        XCTAssertEqual(attributes["device.family"]?.value as? String, "iOS")
    }
    
    func testAddItem_HandlesPartialOSAndDeviceAttributes() throws {
        // -- Arrange --
        let osContext = ["name": "macOS"]
        let deviceContext = ["family": "macOS"]
        scope.setContext(value: osContext, key: "os")
        scope.setContext(value: deviceContext, key: "device")
        let sut = getSut()
        let item = createTestItem(body: "Test item message")
        
        // -- Act --
        sut.addItem(item, scope: scope)
        sut.captureItems()
        
        // -- Assert --
        let capturedItems = testDelegate.getCapturedItems()
        let capturedItem = try XCTUnwrap(capturedItems.first)
        let attributes = capturedItem.attributes
        
        XCTAssertEqual(attributes["os.name"]?.value as? String, "macOS")
        XCTAssertNil(attributes["os.version"])
        XCTAssertEqual(attributes["device.brand"]?.value as? String, "Apple")
        XCTAssertNil(attributes["device.model"])
        XCTAssertEqual(attributes["device.family"]?.value as? String, "macOS")
    }
    
    func testAddItem_HandlesMissingOSAndDeviceContext() throws {
        // -- Arrange --
        scope.removeContext(key: "os")
        scope.removeContext(key: "device")
        let sut = getSut()
        let item = createTestItem(body: "Test item message")
        
        // -- Act --
        sut.addItem(item, scope: scope)
        sut.captureItems()
        
        // -- Assert --
        let capturedItems = testDelegate.getCapturedItems()
        let capturedItem = try XCTUnwrap(capturedItems.first)
        let attributes = capturedItem.attributes
        
        XCTAssertNil(attributes["os.name"])
        XCTAssertNil(attributes["os.version"])
        XCTAssertNil(attributes["device.brand"])
        XCTAssertNil(attributes["device.model"])
        XCTAssertNil(attributes["device.family"])
    }
    
    func testAddItem_AddsScopeAttributes() throws {
        // -- Arrange --
        let scope = Scope()
        scope.setAttribute(value: "aString", key: "string-attribute")
        scope.setAttribute(value: false, key: "bool-attribute")
        scope.setAttribute(value: 1.765, key: "double-attribute")
        scope.setAttribute(value: 5, key: "integer-attribute")
        let sut = getSut()
        let item = createTestItem(body: "Test item message")
        
        // -- Act --
        sut.addItem(item, scope: scope)
        sut.captureItems()
        
        // -- Assert --
        let capturedItems = testDelegate.getCapturedItems()
        let capturedItem = try XCTUnwrap(capturedItems.first)
        let attributes = capturedItem.attributes
        
        XCTAssertEqual(attributes["string-attribute"]?.value as? String, "aString")
        XCTAssertEqual(attributes["string-attribute"]?.type, "string")
        XCTAssertEqual(attributes["bool-attribute"]?.value as? Bool, false)
        XCTAssertEqual(attributes["bool-attribute"]?.type, "boolean")
        XCTAssertEqual(attributes["double-attribute"]?.value as? Double, 1.765)
        XCTAssertEqual(attributes["double-attribute"]?.type, "double")
        XCTAssertEqual(attributes["integer-attribute"]?.value as? Int, 5)
        XCTAssertEqual(attributes["integer-attribute"]?.type, "integer")
    }
    
    func testAddItem_ScopeAttributesDoNotOverrideItemAttribute() throws {
        // -- Arrange --
        let scope = Scope()
        scope.setAttribute(value: true, key: "item-attribute")
        let sut = getSut()
        let item = createTestItem(body: "Test item message", attributes: ["item-attribute": .init(boolean: false)])
        
        // -- Act --
        sut.addItem(item, scope: scope)
        sut.captureItems()
        
        // -- Assert --
        let capturedItems = testDelegate.getCapturedItems()
        let capturedItem = try XCTUnwrap(capturedItems.first)
        let attributes = capturedItem.attributes
        
        XCTAssertEqual(attributes["item-attribute"]?.value as? Bool, false)
        XCTAssertEqual(attributes["item-attribute"]?.type, "boolean")
    }
    
    // MARK: - Replay Attributes Tests
    
#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)
    func testAddItem_ReplayAttributes_SessionMode_AddsReplayId() throws {
        // -- Arrange --
        let replayId = "12345678-1234-1234-1234-123456789012"
        scope.replayId = replayId
        let sut = getSut()
        let item = createTestItem(body: "Test message")
        
        // -- Act --
        sut.addItem(item, scope: scope)
        sut.captureItems()
        
        // -- Assert --
        let capturedItems = testDelegate.getCapturedItems()
        let capturedItem = try XCTUnwrap(capturedItems.first)
        XCTAssertEqual(capturedItem.attributes["sentry.replay_id"]?.value as? String, replayId)
    }
    
    func testAddItem_ReplayAttributes_NoReplayId_NoAttributesAdded() throws {
        // -- Arrange --
        scope.replayId = nil
        let sut = getSut()
        let item = createTestItem(body: "Test message")
        
        // -- Act --
        sut.addItem(item, scope: scope)
        sut.captureItems()
        
        // -- Assert --
        let capturedItems = testDelegate.getCapturedItems()
        let capturedItem = try XCTUnwrap(capturedItems.first)
        XCTAssertNil(capturedItem.attributes["sentry.replay_id"])
    }
#endif
#endif
    
    // MARK: - BeforeSendItem Callback Tests
    
    func testBeforeSendItem_ReturnsModifiedItem() throws {
        // -- Arrange --
        var beforeSendCalled = false
        let config = SentryItemBatcher<TestItem>.Config(
            beforeSendItem: { item in
                beforeSendCalled = true
                
                XCTAssertEqual(item.body, "Original message")
                
                var modifiedItem = item
                modifiedItem.body = "Modified by callback"
                modifiedItem.attributes["callback_modified"] = SentryAttribute(boolean: true)
                
                return modifiedItem
            },
            environment: options.environment,
            releaseName: options.releaseName,
            flushTimeout: 0.1,
            maxItemCount: 10,
            maxBufferSizeBytes: 8_000,
            getInstallationId: { [options] in
                SentryInstallation.cachedId(withCacheDirectoryPath: options.cacheDirectoryPath)
            }
        )
        
        let sutWithCallback = SentryItemBatcher<TestItem>(
            config: config,
            dispatchQueue: testDispatchQueue
        )
        sutWithCallback.delegate = testDelegate
        let item = createTestItem(body: "Original message")
        
        // -- Act --
        sutWithCallback.addItem(item, scope: scope)
        sutWithCallback.captureItems()
        
        // -- Assert --
        XCTAssertTrue(beforeSendCalled)
        
        let capturedItems = testDelegate.getCapturedItems()
        let capturedItem = try XCTUnwrap(capturedItems.first)
        XCTAssertEqual(capturedItem.body, "Modified by callback")
        XCTAssertEqual(capturedItem.attributes["callback_modified"]?.value as? Bool, true)
    }
    
    func testBeforeSendItem_ReturnsNil_ItemNotCaptured() {
        // -- Arrange --
        var beforeSendCalled = false
        let config = SentryItemBatcher<TestItem>.Config(
            beforeSendItem: { _ in
                beforeSendCalled = true
                return nil // Drop the item
            },
            environment: options.environment,
            releaseName: options.releaseName,
            flushTimeout: 0.1,
            maxItemCount: 10,
            maxBufferSizeBytes: 8_000,
            getInstallationId: { [options] in
                SentryInstallation.cachedId(withCacheDirectoryPath: options.cacheDirectoryPath)
            }
        )
        
        let sutWithCallback = SentryItemBatcher<TestItem>(
            config: config,
            dispatchQueue: testDispatchQueue
        )
        sutWithCallback.delegate = testDelegate
        let item = createTestItem(body: "This item should be dropped")
        
        // -- Act --
        sutWithCallback.addItem(item, scope: scope)
        sutWithCallback.captureItems()
        
        // -- Assert --
        XCTAssertTrue(beforeSendCalled)
        XCTAssertEqual(testDelegate.captureItemsBatcherDataInvocations.count, 0)
    }
    
    func testBeforeSendItem_NotSet_ItemCapturedUnmodified() throws {
        // -- Arrange --
        let sut = getSut()
        let item = createTestItem(body: "Debug message")
        
        // -- Act --
        sut.addItem(item, scope: scope)
        sut.captureItems()
        
        // -- Assert --
        let capturedItems = testDelegate.getCapturedItems()
        XCTAssertEqual(capturedItems.count, 1)
        
        let capturedItem = try XCTUnwrap(capturedItems.first)
        XCTAssertEqual(capturedItem.body, "Debug message")
    }
    
    func testBeforeSendItem_PreservesOriginalItemAttributes() throws {
        // -- Arrange --
        let config = SentryItemBatcher<TestItem>.Config(
            beforeSendItem: { item in
                var modifiedItem = item
                modifiedItem.attributes["added_by_callback"] = SentryAttribute(string: "callback_value")
                return modifiedItem
            },
            environment: options.environment,
            releaseName: options.releaseName,
            flushTimeout: 0.1,
            maxItemCount: 10,
            maxBufferSizeBytes: 8_000,
            getInstallationId: { [options] in
                SentryInstallation.cachedId(withCacheDirectoryPath: options.cacheDirectoryPath)
            }
        )
        
        let sutWithCallback = SentryItemBatcher<TestItem>(
            config: config,
            dispatchQueue: testDispatchQueue
        )
        sutWithCallback.delegate = testDelegate
        
        let itemAttributes: [String: SentryAttribute] = [
            "original_key": SentryAttribute(string: "original_value"),
            "user_id": SentryAttribute(integer: 12_345)
        ]
        let item = createTestItem(body: "Test message", attributes: itemAttributes)
        
        // -- Act --
        sutWithCallback.addItem(item, scope: scope)
        sutWithCallback.captureItems()
        
        // -- Assert --
        let capturedItems = testDelegate.getCapturedItems()
        let capturedItem = try XCTUnwrap(capturedItems.first)
        let attributes = capturedItem.attributes
        
        XCTAssertEqual(attributes["original_key"]?.value as? String, "original_value")
        XCTAssertEqual(attributes["user_id"]?.value as? Int, 12_345)
        XCTAssertEqual(attributes["added_by_callback"]?.value as? String, "callback_value")
    }
    
    // MARK: - Helper Methods
    
    private func createTestItem(
        body: String = "Test item message",
        attributes: [String: SentryAttribute] = [:]
    ) -> TestItem {
        return TestItem(
            attributes: attributes,
            traceId: SentryId.empty,
            body: body
        )
    }
}

// MARK: - Test Item Type

struct TestItem: SentryItemBatcherItem {
    var attributes: [String: SentryAttribute]
    var traceId: SentryId
    var body: String
    
    enum CodingKeys: String, CodingKey {
        case body
        case traceId = "trace_id"
        case attributes
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(body, forKey: .body)
        try container.encode(traceId.sentryIdString, forKey: .traceId)
        try container.encode(attributes, forKey: .attributes)
    }
}

// MARK: - Test Helpers

final class TestItemBatcherDelegate: NSObject, SentryItemBatcherDelegate {
    var captureItemsBatcherDataInvocations = Invocations<(data: Data, count: Int)>()
    
    func capture(itemBatcherData: Data, count: Int) {
        captureItemsBatcherDataInvocations.record((itemBatcherData, count))
    }
    
    // Helper to get captured items
    func getCapturedItems() -> [TestItem] {
        var allItems: [TestItem] = []
        
        for invocation in captureItemsBatcherDataInvocations.invocations {
            if let jsonObject = try? JSONSerialization.jsonObject(with: invocation.data) as? [String: Any],
               let items = jsonObject["items"] as? [[String: Any]] {
                for item in items {
                    if let testItem = parseTestItem(from: item) {
                        allItems.append(testItem)
                    }
                }
            }
        }
        
        return allItems
    }
    
    private func parseTestItem(from dict: [String: Any]) -> TestItem? {
        guard let body = dict["body"] as? String else {
            return nil
        }
        
        let traceIdString = dict["trace_id"] as? String ?? ""
        let traceId = SentryId(uuidString: traceIdString)
        
        var attributes: [String: SentryAttribute] = [:]
        if let attributesDict = dict["attributes"] as? [String: [String: Any]] {
            for (key, value) in attributesDict {
                if let attrValue = value["value"] {
                    attributes[key] = SentryAttribute(value: attrValue)
                }
            }
        }
        
        return TestItem(attributes: attributes, traceId: traceId, body: body)
    }
}
