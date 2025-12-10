@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

final class SentryItemBatcherTests: XCTestCase {
    private struct TestItem: SentryItemBatcherItem, Codable {
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

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            body = try container.decode(String.self, forKey: .body)
            
            let traceIdString = try container.decode(String.self, forKey: .traceId)
            traceId = SentryId(uuidString: traceIdString)
            
            // Decode attributes dictionary
            let attributesDict = try container.decode([String: SentryAttributeCodable].self, forKey: .attributes)
            attributes = attributesDict.mapValues { codableAttr in
                switch codableAttr.type {
                case "string":
                    return SentryAttribute(string: codableAttr.value.value as! String)
                case "boolean":
                    return SentryAttribute(boolean: codableAttr.value.value as! Bool)
                case "integer":
                    return SentryAttribute(integer: codableAttr.value.value as! Int)
                case "double":
                    return SentryAttribute(double: codableAttr.value.value as! Double)
                default:
                    return SentryAttribute(value: codableAttr.value.value)
                }
            }
        }

        init(attributes: [String: SentryAttribute], traceId: SentryId, body: String) {
            self.attributes = attributes
            self.traceId = traceId
            self.body = body
        }
    }

    // Helper struct for decoding SentryAttribute from JSON
    private struct SentryAttributeCodable: Codable {
        let type: String
        let value: AnyCodableValue

        enum CodingKeys: String, CodingKey {
            case type
            case value
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            type = try container.decode(String.self, forKey: .type)
            value = try container.decode(AnyCodableValue.self, forKey: .value)
        }
    }

    // Helper enum to decode Any value from JSON
    private enum AnyCodableValue: Codable {
        case string(String)
        case bool(Bool)
        case int(Int)
        case double(Double)

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let stringValue = try? container.decode(String.self) {
                self = .string(stringValue)
            } else if let boolValue = try? container.decode(Bool.self) {
                self = .bool(boolValue)
            } else if let intValue = try? container.decode(Int.self) {
                self = .int(intValue)
            } else if let doubleValue = try? container.decode(Double.self) {
                self = .double(doubleValue)
            } else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported value type")
            }
        }

        var value: Any {
            switch self {
            case .string(let v): return v
            case .bool(let v): return v
            case .int(let v): return v
            case .double(let v): return v
            }
        }
    }

    // Batch payload structure for decoding
    private struct BatchPayload: Codable {
        let items: [TestItem]
    }

    // Minimal test scope that conforms to SentryItemBatcherScope
    private struct TestScope: SentryItemBatcherScope {
        var replayId: String?
        var propagationContext: SentryPropagationContext?
        var span: Span?
        var userObject: User?
        var contextStore: [String: [String: Any]] = [:]
        var attributes: [String: Any] = [:]

        var propagationContextTraceIdString: String {
            return propagationContext?.traceId.sentryIdString ?? SentryId().sentryIdString
        }

        func getContextForKey(_ key: String) -> [String: Any]? {
            return contextStore[key]
        }

        mutating func setUser(_ user: User?) {
            userObject = user
        }

        mutating func setContext(value: [String: Any], key: String) {
            contextStore[key] = value
        }

        mutating func removeContext(key: String) {
            contextStore.removeValue(forKey: key)
        }
    }

    private var options: Options!
    private var testDateProvider: TestCurrentDateProvider!
    private var testDispatchQueue: TestSentryDispatchQueueWrapper!
    private var scope: TestScope!
    private var capturedDataInvocations: [(data: Data, count: Int)] = []

    private func getSut() -> SentryItemBatcher<TestItem, TestScope> {
        var config = SentryItemBatcher<TestItem, TestScope>.Config(
            environment: options.environment,
            releaseName: options.releaseName,
            flushTimeout: 0.1, // Very small timeout for testing
            maxItemCount: 10, // Maximum 10 items per batch
            maxBufferSizeBytes: 8_000, // byte limit for testing (item with attributes ~390 bytes)
            beforeSendItem: nil,
            getInstallationId: { [options] in
                SentryInstallation.cachedId(withCacheDirectoryPath: options.cacheDirectoryPath)
            }
        )
        config.capturedDataCallback = { [weak self] data, count in
            self?.capturedDataInvocations.append((data, count))
        }
        
        return SentryItemBatcher<TestItem, TestScope>(
            config: config,
            dateProvider: testDateProvider,
            dispatchQueue: testDispatchQueue
        )
    }

    override func setUp() {
        super.setUp()
        
        options = Options()
        options.dsn = TestConstants.dsnForTestCase(type: Self.self)
        options.environment = "test-environment"
        
        capturedDataInvocations = []
        testDateProvider = TestCurrentDateProvider()
        testDispatchQueue = TestSentryDispatchQueueWrapper()
        testDispatchQueue.dispatchAsyncExecutesBlock = true // Execute encoding immediately

        scope = TestScope()
    }
    
    override func tearDown() {
        super.tearDown()
        capturedDataInvocations = []
        testDispatchQueue = nil
        scope = nil
    }

    // MARK: - Helper Methods

    /// Decodes all captured items from all invocations using Codable
    private func getCapturedItems() -> [TestItem] {
        var allItems: [TestItem] = []
        
        for invocation in capturedDataInvocations {
            if let batchPayload = try? JSONDecoder().decode(BatchPayload.self, from: invocation.data) {
                allItems.append(contentsOf: batchPayload.items)
            }
        }
        
        return allItems
    }
    
    // MARK: - Basic Functionality Tests
    
    func testAddMultipleItems_BatchesTogether() throws {
        // -- Arrange --
        let sut = getSut()
        let item1 = createTestItem(body: "Item 1")
        let item2 = createTestItem(body: "Item 2")
        
        // -- Act --
        sut.add(item1, scope: scope)
        sut.add(item2, scope: scope)
        _ = sut.capture()
        
        // -- Assert --
        XCTAssertEqual(capturedDataInvocations.count, 1)
        
        let capturedItems = getCapturedItems()
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
        sut.add(largeItem, scope: scope)

        // -- Assert --
        XCTAssertEqual(capturedDataInvocations.count, 1)
        
        // Verify the large item is sent
        let capturedItems = getCapturedItems()
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
            sut.add(item, scope: scope)
        }
        
        XCTAssertEqual(capturedDataInvocations.count, 0)
        
        let item = createTestItem(body: "Item \(10)") // Reached 10 max items limit
        sut.add(item, scope: scope)
        
        // -- Assert --
        XCTAssertEqual(capturedDataInvocations.count, 1)
        
        let capturedItems = getCapturedItems()
        XCTAssertEqual(capturedItems.count, 10, "Should have captured exactly \(10) items")
    }
    
    // MARK: - Timeout Tests
    
    func testTimeout_FlushesAfterDelay() throws {
        // -- Arrange --
        let sut = getSut()
        let item = createTestItem()

        // -- Act --
        sut.add(item, scope: scope)
        testDispatchQueue.invokeLastDispatchAfterWorkItem()
        
        // -- Assert --
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.count, 1)
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.first?.interval, 0.1)
        XCTAssertEqual(capturedDataInvocations.count, 1)
        
        let capturedItems = getCapturedItems()
        XCTAssertEqual(capturedItems.count, 1)
    }
    
    func testAddingItemToEmptyBuffer_StartsTimer() throws {
        // -- Arrange --
        let sut = getSut()
        let item1 = createTestItem(body: "Item 1")
        let item2 = createTestItem(body: "Item 2")
        
        // -- Act --
        sut.add(item1, scope: scope)
        sut.add(item2, scope: scope)
        testDispatchQueue.invokeLastDispatchAfterWorkItem()
        
        // -- Assert --
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.count, 1)
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.first?.interval, 0.1)
        XCTAssertEqual(capturedDataInvocations.count, 1)
        
        let capturedItems = getCapturedItems()
        XCTAssertEqual(capturedItems.count, 2)
    }
    
    // MARK: - Manual Capture Items Tests
    
    func testManualCaptureItems_CapturesImmediately() throws {
        // -- Arrange --
        let sut = getSut()
        let item1 = createTestItem(body: "Item 1")
        let item2 = createTestItem(body: "Item 2")
        
        // -- Act --
        sut.add(item1, scope: scope)
        sut.add(item2, scope: scope)
        _ = sut.capture()
        
        // -- Assert --
        XCTAssertEqual(capturedDataInvocations.count, 1)
        
        let capturedItems = getCapturedItems()
        XCTAssertEqual(capturedItems.count, 2)
    }
    
    func testManualCaptureItems_CancelsScheduledCapture() throws {
        // -- Arrange --
        let sut = getSut()
        let item = createTestItem()
        sut.add(item, scope: scope)
        let timerWorkItem = try XCTUnwrap(testDispatchQueue.dispatchAfterWorkItemInvocations.first?.workItem)
        
        // -- Act --
        _ = sut.capture()
        timerWorkItem.perform()
        
        // -- Assert --
        XCTAssertEqual(capturedDataInvocations.count, 1, "Manual flush should work and timer should be cancelled")
    }
    
    func testManualCaptureItems_WithEmptyBuffer_DoesNothing() {
        // -- Arrange --
        let sut = getSut()

        // -- Act --
        _ = sut.capture()
        
        // -- Assert --
        XCTAssertEqual(capturedDataInvocations.count, 0)
    }
    
    // MARK: - Edge Cases Tests
    
    func testScheduledFlushAfterBufferAlreadyFlushed_DoesNothing() throws {
        // -- Arrange --
        let sut = getSut()
        let largeItemBody = String(repeating: "B", count: 4_000)
        let item1 = createTestItem(body: largeItemBody)
        let item2 = createTestItem(body: largeItemBody)
        
        // -- Act --
        sut.add(item1, scope: scope)
        let timerWorkItem = try XCTUnwrap(testDispatchQueue.dispatchAfterWorkItemInvocations.first?.workItem)
        sut.add(item2, scope: scope)
        timerWorkItem.perform()
        
        // -- Assert --
        XCTAssertEqual(capturedDataInvocations.count, 1)
    }
    
    func testAddItemAfterFlush_StartsNewBatch() throws {
        // -- Arrange --
        let sut = getSut()
        let item1 = createTestItem(body: "Item 1")
        let item2 = createTestItem(body: "Item 2")
        
        // -- Act --
        sut.add(item1, scope: scope)
        _ = sut.capture()
        sut.add(item2, scope: scope)
        _ = sut.capture()
        
        // -- Assert --
        XCTAssertEqual(capturedDataInvocations.count, 2)
        
        let allCapturedItems = getCapturedItems()
        XCTAssertEqual(allCapturedItems.count, 2)
        XCTAssertEqual(allCapturedItems[0].body, "Item 1")
        XCTAssertEqual(allCapturedItems[1].body, "Item 2")
    }
    
    // MARK: - Integration Tests
    
    func testConcurrentAdds_ThreadSafe() throws {
        // -- Arrange --
        var config = SentryItemBatcher<TestItem, TestScope>.Config(
            environment: options.environment,
            releaseName: options.releaseName,
            flushTimeout: 5,
            maxItemCount: 1_000, // Maximum 1000 items per batch
            maxBufferSizeBytes: 10_000,
            beforeSendItem: nil,
            getInstallationId: { [options] in
                SentryInstallation.cachedId(withCacheDirectoryPath: options.cacheDirectoryPath)
            }
        )
        config.capturedDataCallback = { [weak self] data, count in
            self?.capturedDataInvocations.append((data, count))
        }
        
        let sutWithRealQueue = SentryItemBatcher<TestItem, TestScope>(
            config: config,
            dateProvider: TestCurrentDateProvider(),
            dispatchQueue: SentryDispatchQueueWrapper()
        )
        
        let expectation = XCTestExpectation(description: "Concurrent adds")
        expectation.expectedFulfillmentCount = 10
        
        // -- Act --
        for i in 0..<10 {
            DispatchQueue.global().async {
                let item = self.createTestItem(body: "Item \(i)")
                sutWithRealQueue.add(item, scope: self.scope)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 1.0)
        _ = sutWithRealQueue.capture()
        
        // -- Assert --
        let capturedItems = getCapturedItems()
        XCTAssertEqual(capturedItems.count, 10, "All 10 concurrently added items should be in the batch")
    }

    func testDispatchAfterTimeoutWithRealDispatchQueue() throws {
        // -- Arrange --
        var config = SentryItemBatcher<TestItem, TestScope>.Config(
            environment: options.environment,
            releaseName: options.releaseName,
            flushTimeout: 0.2,
            maxItemCount: 1_000, // Maximum 1000 items per batch
            maxBufferSizeBytes: 10_000,
            beforeSendItem: nil,
            getInstallationId: { [options] in
                SentryInstallation.cachedId(withCacheDirectoryPath: options.cacheDirectoryPath)
            }
        )
        config.capturedDataCallback = { [weak self] data, count in
            self?.capturedDataInvocations.append((data, count))
        }
        
        let sutWithRealQueue = SentryItemBatcher<TestItem, TestScope>(
            config: config,
            dateProvider: TestCurrentDateProvider(),
            dispatchQueue: SentryDispatchQueueWrapper()
        )
        
        let item = createTestItem(body: "Real timeout test item")
        let expectation = XCTestExpectation(description: "Real timeout flush")
        
        // -- Act --
        sutWithRealQueue.add(item, scope: scope)
        XCTAssertEqual(capturedDataInvocations.count, 0)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // -- Assert --
        XCTAssertEqual(capturedDataInvocations.count, 1, "Timeout should trigger flush")
        
        let capturedItems = getCapturedItems()
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
        sut.add(item, scope: scope)
        _ = sut.capture()
        
        // -- Assert --
        let capturedItems = getCapturedItems()
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
        sut.add(item, scope: scope)
        _ = sut.capture()
        
        // -- Assert --
        let capturedItems = getCapturedItems()
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
        sut.add(item, scope: scope)
        _ = sut.capture()
        
        // -- Assert --
        let capturedItems = getCapturedItems()
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
        sut.add(item, scope: scope)
        _ = sut.capture()
        
        // -- Assert --
        let capturedItems = getCapturedItems()
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
        sut.add(item, scope: scope)
        _ = sut.capture()
        
        // -- Assert --
        let capturedItems = getCapturedItems()
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
        sut.add(item, scope: scope)
        _ = sut.capture()
        
        // -- Assert --
        let capturedItems = getCapturedItems()
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
        sut.add(item, scope: scope)
        _ = sut.capture()
        
        // -- Assert --
        let capturedItems = getCapturedItems()
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
        sut.add(item, scope: scope)
        _ = sut.capture()
        
        // -- Assert --
        let capturedItems = getCapturedItems()
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
        sut.add(item, scope: scope)
        _ = sut.capture()
        
        // -- Assert --
        let capturedItems = getCapturedItems()
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
        sut.add(item, scope: scope)
        _ = sut.capture()
        
        // -- Assert --
        let capturedItems = getCapturedItems()
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
        let scope = TestScope(attributes: [
            "string-attribute": "aString",
            "bool-attribute": false,
            "double-attribute": 1.765,
            "integer-attribute": 5
        ])
        let sut = getSut()
        let item = createTestItem(body: "Test item message")
        
        // -- Act --
        sut.add(item, scope: scope)
        _ = sut.capture()
        
        // -- Assert --
        let capturedItems = getCapturedItems()
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
        let scope = TestScope(attributes: [
            "item-attribute": true
        ])
        let sut = getSut()
        let item = createTestItem(body: "Test item message", attributes: ["item-attribute": .init(boolean: false)])
        
        // -- Act --
        sut.add(item, scope: scope)
        _ = sut.capture()
        
        // -- Assert --
        let capturedItems = getCapturedItems()
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
        sut.add(item, scope: scope)
        _ = sut.capture()
        
        // -- Assert --
        let capturedItems = getCapturedItems()
        let capturedItem = try XCTUnwrap(capturedItems.first)
        XCTAssertEqual(capturedItem.attributes["sentry.replay_id"]?.value as? String, replayId)
    }
    
    func testAddItem_ReplayAttributes_NoReplayId_NoAttributesAdded() throws {
        // -- Arrange --
        scope.replayId = nil
        let sut = getSut()
        let item = createTestItem(body: "Test message")
        
        // -- Act --
        sut.add(item, scope: scope)
        _ = sut.capture()
        
        // -- Assert --
        let capturedItems = getCapturedItems()
        let capturedItem = try XCTUnwrap(capturedItems.first)
        XCTAssertNil(capturedItem.attributes["sentry.replay_id"])
    }
#endif
#endif
    
    // MARK: - BeforeSendItem Callback Tests
    
    func testBeforeSendItem_ReturnsModifiedItem() throws {
        // -- Arrange --
        var beforeSendCalled = false
        var config = SentryItemBatcher<TestItem, TestScope>.Config(
            environment: options.environment,
            releaseName: options.releaseName,
            flushTimeout: 0.1,
            maxItemCount: 10,
            maxBufferSizeBytes: 8_000,
            beforeSendItem: { item in
                beforeSendCalled = true

                XCTAssertEqual(item.body, "Original message")

                var modifiedItem = item
                modifiedItem.body = "Modified by callback"
                modifiedItem.attributes["callback_modified"] = SentryAttribute(boolean: true)

                return modifiedItem
            },
            getInstallationId: { [options] in
                SentryInstallation.cachedId(withCacheDirectoryPath: options.cacheDirectoryPath)
            }
        )
        
        config.capturedDataCallback = { [weak self] data, count in
            self?.capturedDataInvocations.append((data, count))
        }
        
        let sutWithCallback = SentryItemBatcher<TestItem, TestScope>(
            config: config,
            dateProvider: TestCurrentDateProvider(),
            dispatchQueue: testDispatchQueue
        )
        let item = createTestItem(body: "Original message")
        
        // -- Act --
        sutWithCallback.add(item, scope: scope)
        _ = sutWithCallback.capture()
        
        // -- Assert --
        XCTAssertTrue(beforeSendCalled)
        
        let capturedItems = getCapturedItems()
        let capturedItem = try XCTUnwrap(capturedItems.first)
        XCTAssertEqual(capturedItem.body, "Modified by callback")
        XCTAssertEqual(capturedItem.attributes["callback_modified"]?.value as? Bool, true)
    }
    
    func testBeforeSendItem_ReturnsNil_ItemNotCaptured() {
        // -- Arrange --
        var beforeSendCalled = false
        var config = SentryItemBatcher<TestItem, TestScope>.Config(
            environment: options.environment,
            releaseName: options.releaseName,
            flushTimeout: 0.1,
            maxItemCount: 10,
            maxBufferSizeBytes: 8_000,
            beforeSendItem: { _ in
                beforeSendCalled = true
                return nil // Drop the item
            },
            getInstallationId: { [options] in
                SentryInstallation.cachedId(withCacheDirectoryPath: options.cacheDirectoryPath)
            }
        )
        config.capturedDataCallback = { [weak self] data, count in
            self?.capturedDataInvocations.append((data, count))
        }
        
        let sutWithCallback = SentryItemBatcher<TestItem, TestScope>(
            config: config,
            dateProvider: TestCurrentDateProvider(),
            dispatchQueue: testDispatchQueue
        )
        let item = createTestItem(body: "This item should be dropped")
        
        // -- Act --
        sutWithCallback.add(item, scope: scope)
        _ = sutWithCallback.capture()
        
        // -- Assert --
        XCTAssertTrue(beforeSendCalled)
        XCTAssertEqual(capturedDataInvocations.count, 0)
    }
    
    func testBeforeSendItem_NotSet_ItemCapturedUnmodified() throws {
        // -- Arrange --
        let sut = getSut()
        let item = createTestItem(body: "Debug message")
        
        // -- Act --
        sut.add(item, scope: scope)
        _ = sut.capture()
        
        // -- Assert --
        let capturedItems = getCapturedItems()
        XCTAssertEqual(capturedItems.count, 1)
        
        let capturedItem = try XCTUnwrap(capturedItems.first)
        XCTAssertEqual(capturedItem.body, "Debug message")
    }
    
    func testBeforeSendItem_PreservesOriginalItemAttributes() throws {
        // -- Arrange --
        var config = SentryItemBatcher<TestItem, TestScope>.Config(
            environment: options.environment,
            releaseName: options.releaseName,
            flushTimeout: 0.1,
            maxItemCount: 10,
            maxBufferSizeBytes: 8_000,
            beforeSendItem: { item in
                var modifiedItem = item
                modifiedItem.attributes["added_by_callback"] = SentryAttribute(string: "callback_value")
                return modifiedItem
            },
            getInstallationId: { [options] in
                SentryInstallation.cachedId(withCacheDirectoryPath: options.cacheDirectoryPath)
            }
        )
        
        config.capturedDataCallback = { [weak self] data, count in
            self?.capturedDataInvocations.append((data, count))
        }
        
        let sutWithCallback = SentryItemBatcher<TestItem, TestScope>(
            config: config,
            dateProvider: TestCurrentDateProvider(),
            dispatchQueue: testDispatchQueue
        )
        
        let itemAttributes: [String: SentryAttribute] = [
            "original_key": SentryAttribute(string: "original_value"),
            "user_id": SentryAttribute(integer: 12_345)
        ]
        let item = createTestItem(body: "Test message", attributes: itemAttributes)
        
        // -- Act --
        sutWithCallback.add(item, scope: scope)
        _ = sutWithCallback.capture()
        
        // -- Assert --
        let capturedItems = getCapturedItems()
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
