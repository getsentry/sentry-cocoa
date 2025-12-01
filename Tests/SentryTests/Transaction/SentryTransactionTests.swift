@_spi(Private) @testable import Sentry
import SentryTestUtils
import XCTest

class SentryTransactionTests: XCTestCase {
    
    private class Fixture {
        let transactionName = "Some Transaction"
        let transactionOperation = "ui.load"
        let traceOrigin = "auto"
        let testKey = "extra_key"
        let testValue = "extra_value"
        
        func getTransaction(trace: SentryTracer = SentryTracer(transactionContext: TransactionContext(operation: "operation"), hub: TestHub(client: nil, andScope: nil))) -> Transaction {
            return Transaction(trace: trace, children: [])
        }
        
        func getContext() -> TransactionContext {
            return TransactionContext(name: transactionName, nameSource: .component, operation: transactionOperation, origin: traceOrigin)
        }
        
        func getTrace() -> SentryTracer {
            return SentryTracer(transactionContext: getContext(), hub: nil)
        }
        
        func getHub() -> SentryHubInternal {
            let scope = Scope()
            let client = TestClient(options: Options())!
            client.options.tracesSampleRate = 1
            return TestHub(client: client, andScope: scope)
        }
        
        func getTransactionWith(scope: Scope) -> Transaction {
            let client = TestClient(options: Options())!
            client.options.tracesSampleRate = 1
            
            let hub = TestHub(client: client, andScope: scope)
            let trace = SentryTracer(transactionContext: self.getContext(), hub: hub)
            let transaction = Transaction(trace: trace, children: [])
            return transaction
        }        
    }
    
    private var fixture: Fixture!
    
    override func setUp() {
        super.setUp()
        fixture = Fixture()
    }
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

    func testSerializeMeasurements_NoMeasurements() {
        let actual = fixture.getTransaction().serialize()
        
        XCTAssertNil(actual["measurements"])
    }
    
    func testSerializeMeasurements_DurationMeasurement() {
        let name = "some_duration"
        let value: NSNumber = 15_000.0
        let unit = MeasurementUnitDuration.millisecond
        
        let trace = SentryTracer(transactionContext: TransactionContext(operation: "operation"), hub: TestHub(client: nil, andScope: nil))
        trace.setMeasurement(name: name, value: value, unit: unit)
        let transaction = fixture.getTransaction(trace: trace)

        let actual = transaction.serialize()
        
        let actualMeasurements = actual["measurements"] as? [String: [String: Any]]
        XCTAssertNotNil(actualMeasurements)
        
        let coldStartMeasurement = actualMeasurements?[name]
        XCTAssertEqual(value, try XCTUnwrap(coldStartMeasurement?["value"] as? NSNumber))
        XCTAssertEqual(unit.unit, try XCTUnwrap(coldStartMeasurement?["unit"] as? String))
    }
    
    func testSerializeMeasurements_MultipleMeasurements() {
        let frameName = "frames_total"
        let frameValue: NSNumber = 60
        
        let customName = "custom-name"
        let customValue: NSNumber = 20.1
        let customUnit = MeasurementUnit(unit: "custom")
        
        let trace = SentryTracer(transactionContext: TransactionContext(operation: "operation"), hub: TestHub(client: nil, andScope: nil))
        trace.setMeasurement(name: frameName, value: frameValue)
        trace.setMeasurement(name: customName, value: customValue, unit: customUnit)
        let transaction = fixture.getTransaction(trace: trace)
        
        let actual = transaction.serialize()
        
        let actualMeasurements = actual["measurements"] as? [String: [String: Any]]
        XCTAssertNotNil(actualMeasurements)
        
        let frameMeasurement = actualMeasurements?[frameName]
        XCTAssertEqual(frameValue, try XCTUnwrap(frameMeasurement?["value"] as? NSNumber))
        XCTAssertNil(frameMeasurement?["unit"])
        
        let customMeasurement = actualMeasurements?[customName]
        XCTAssertEqual(customValue, try XCTUnwrap(customMeasurement?["value"] as? NSNumber))
        XCTAssertEqual(customUnit.unit, try XCTUnwrap(customMeasurement?["unit"] as? String))
    }
    
    func testSerialize_Tags() throws {
        // given
        let trace = fixture.getTrace()
        trace.setTag(value: fixture.testValue, key: fixture.testKey)
        
        let sut = Transaction(trace: trace, children: [])
        
        // when
        let serializedTransaction = sut.serialize()
        let serializedTransactionTags = try XCTUnwrap(serializedTransaction["tags"] as? [String: String])
        
        // then
        XCTAssertEqual(serializedTransactionTags, [fixture.testKey: fixture.testValue])
    }
    
    func testSerialize_shouldPreserveTagsFromScope() throws {
        // given
        let scope = Scope()
        scope.setTag(value: fixture.testValue, key: fixture.testKey)
        let transaction = fixture.getTransactionWith(scope: scope)
        
        let sut = try XCTUnwrap(scope.applyTo(event: transaction, maxBreadcrumbs: 0))

        // when
        let serializedTransaction = sut.serialize()
        let serializedTransactionTags = try XCTUnwrap(serializedTransaction["tags"] as? [String: String])
        
        // then
        XCTAssertEqual(serializedTransactionTags, [fixture.testKey: fixture.testValue])
    }
    
    func testSerialize_shouldPreserveExtra() throws {
        // given
        let trace = fixture.getTrace()
        trace.setData(value: fixture.testValue, key: fixture.testKey)
        
        let sut = Transaction(trace: trace, children: [])
        
        // when
        let serializedTransaction = sut.serialize()
        let serializedTransactionExtra = try XCTUnwrap(serializedTransaction["extra"] as? [String: Any])
        
        // then
        XCTAssertEqual(try XCTUnwrap(serializedTransactionExtra[fixture.testKey] as? String), fixture.testValue)
    }
    
    func testSerialize_shouldPreserveExtraFromScope() throws {
        // given
        let scope = Scope()
        scope.setExtra(value: fixture.testValue, key: fixture.testKey)
        
        let transaction = fixture.getTransactionWith(scope: scope)
        
        let sut = try XCTUnwrap(scope.applyTo(event: transaction, maxBreadcrumbs: 0))

        // when
        let serializedTransaction = sut.serialize()
        let serializedTransactionExtra = try XCTUnwrap(serializedTransaction["extra"] as? [String: Any])
        
        // then
        XCTAssertEqual(try XCTUnwrap(serializedTransactionExtra[fixture.testKey] as? String), fixture.testValue)
    }
    
    // MARK: - Tags Tests (Read/Add/Remove/Modify/Replace)
    
    func testReadTags_withTagsOnTracerAndEvent_shouldReturnAllTags() throws {
        // -- Arrange --
        let trace = fixture.getTrace()
        trace.setTag(value: "my-transaction-value", key: "my-transaction-key")
        
        let scope = Scope()
        scope.setTag(value: "scope-tag-value", key: "scope-tag-key")
        
        let transaction = Transaction(trace: trace, children: [])
        _ = scope.applyTo(event: transaction, maxBreadcrumbs: 0)
        
        // -- Act --
        let tags = try XCTUnwrap(transaction.tags)
        
        // -- Assert --
        XCTAssertEqual(tags["my-transaction-key"], "my-transaction-value", "Should read tracer tags")
        XCTAssertEqual(tags["scope-tag-key"], "scope-tag-value", "Should read event/scope tags")
        XCTAssertEqual(tags.count, 2, "Should return all tags")
    }
    
    func testReadTags_withEmptyTags_shouldReturnEmpty() throws {
        // -- Arrange --
        let trace = fixture.getTrace()
        let transaction = Transaction(trace: trace, children: [])
        
        // -- Act --
        let tags = try XCTUnwrap(transaction.tags)
        
        // -- Assert --
        XCTAssertTrue(tags.isEmpty, "Should return empty when no tags are set")
    }
    
    func testAddTags_withExistingTags_shouldAddNewTag() throws {
        // -- Arrange --
        let trace = fixture.getTrace()
        trace.setTag(value: "existing-value", key: "existing-key")
        let transaction = Transaction(trace: trace, children: [])
        
        // -- Act --
        var tags = try XCTUnwrap(transaction.tags)
        tags["new-key"] = "new-value"
        transaction.tags = tags
        
        // -- Assert --
        let tracerTags = trace.tags
        XCTAssertEqual(tracerTags["existing-key"], "existing-value", "Existing tag should remain")
        XCTAssertEqual(tracerTags["new-key"], "new-value", "New tag should be added")
        
        let transactionTags = try XCTUnwrap(transaction.tags)
        XCTAssertEqual(transactionTags["new-key"], "new-value")
        
        let serialized = transaction.serialize()
        let serializedTags = try XCTUnwrap(serialized["tags"] as? [String: String])
        XCTAssertEqual(serializedTags["new-key"], "new-value")
    }
    
    func testModifyTags_withTracerTag_shouldModifyTracerTag() throws {
        // -- Arrange --
        let trace = fixture.getTrace()
        trace.setTag(value: "original-value", key: "my-transaction-key")
        
        let transaction = Transaction(trace: trace, children: [])
        
        // -- Act --
        var tags = try XCTUnwrap(transaction.tags)
        tags["my-transaction-key"] = "modified-value"
        transaction.tags = tags
        
        // -- Assert --
        let tracerTags = trace.tags
        XCTAssertEqual(tracerTags["my-transaction-key"], "modified-value", "Tracer tag should be modified")
        
        let serialized = transaction.serialize()
        let serializedTags = try XCTUnwrap(serialized["tags"] as? [String: String])
        XCTAssertEqual(serializedTags["my-transaction-key"], "modified-value")
        XCTAssertNil(serializedTags["original-value"])
    }
    
    func testModifyTags_withEventTag_shouldModifyEventTag() throws {
        // -- Arrange --
        let scope = Scope()
        scope.setTag(value: "original-language", key: "language")
        
        let trace = fixture.getTrace()
        let transaction = Transaction(trace: trace, children: [])
        _ = scope.applyTo(event: transaction, maxBreadcrumbs: 0)
        
        // -- Act --
        var tags = try XCTUnwrap(transaction.tags)
        tags["language"] = "modified-language"
        transaction.tags = tags
        
        // -- Assert --
        let serialized = transaction.serialize()
        let serializedTags = try XCTUnwrap(serialized["tags"] as? [String: String])
        XCTAssertEqual(serializedTags["language"], "modified-language", "Event tag should be modified")
    }
    
    func testRemoveTags_withTracerTag_shouldRemoveTracerTag() throws {
        // -- Arrange --
        let trace = fixture.getTrace()
        trace.setTag(value: "my-transaction-value", key: "my-transaction-key")
        
        let transaction = Transaction(trace: trace, children: [])
        
        // -- Act --
        var tags = try XCTUnwrap(transaction.tags)
        tags["my-transaction-key"] = nil
        transaction.tags = tags
        
        // -- Assert --
        let tracerTags = trace.tags
        XCTAssertNil(tracerTags["my-transaction-key"], "Tracer tag should be removed")
        
        let serialized = transaction.serialize()
        let serializedTags = try XCTUnwrap(serialized["tags"] as? [String: String])
        XCTAssertNil(serializedTags["my-transaction-key"])
    }
    
    func testRemoveTags_withEventTag_shouldRemoveEventTag() throws {
        // -- Arrange --
        let scope = Scope()
        scope.setTag(value: "swift", key: "language")
        
        let trace = fixture.getTrace()
        let transaction = Transaction(trace: trace, children: [])
        _ = scope.applyTo(event: transaction, maxBreadcrumbs: 0)
        
        // -- Act --
        var tags = try XCTUnwrap(transaction.tags)
        tags["language"] = nil
        transaction.tags = tags
        
        // -- Assert --
        let serialized = transaction.serialize()
        let serializedTags = try XCTUnwrap(serialized["tags"] as? [String: String])
        XCTAssertNil(serializedTags["language"], "Event tag should be removed")
    }
    
    func testReplaceTags_withTagsOnTracerAndEvent_shouldReplaceAllTags() throws {
        // -- Arrange --
        let trace = fixture.getTrace()
        trace.setTag(value: "my-transaction-value", key: "my-transaction-key")
        
        let scope = Scope()
        scope.setTag(value: "swift", key: "language")
        
        let transaction = Transaction(trace: trace, children: [])
        _ = scope.applyTo(event: transaction, maxBreadcrumbs: 0)
        
        // -- Act --
        transaction.tags = ["foo": "bar"]
        
        // -- Assert --
        let tracerTags = trace.tags
        XCTAssertEqual(tracerTags["foo"], "bar", "New tag should be set")
        XCTAssertNil(tracerTags["my-transaction-key"], "Old tracer tag should be removed")
        
        let serialized = transaction.serialize()
        let serializedTags = try XCTUnwrap(serialized["tags"] as? [String: String])
        XCTAssertEqual(serializedTags["foo"], "bar", "New tag should be in serialized output")
        XCTAssertNil(serializedTags["my-transaction-key"], "Old tracer tag should not be in serialized output")
        XCTAssertNil(serializedTags["language"], "Old event tag should not be in serialized output")
    }
    
    func testReplaceTags_withEmptyDictionary_shouldRemoveAllTags() throws {
        // -- Arrange --
        let trace = fixture.getTrace()
        trace.setTag(value: "value1", key: "key1")
        trace.setTag(value: "value2", key: "key2")
        
        let transaction = Transaction(trace: trace, children: [])
        
        // -- Act --
        transaction.tags = [:]
        
        // -- Assert --
        let tracerTags = trace.tags
        XCTAssertEqual(tracerTags.count, 0, "All tracer tags should be removed")
        
        let transactionTags = try XCTUnwrap(transaction.tags)
        XCTAssertEqual(transactionTags.count, 0, "Transaction tags should be empty")
        
        let serialized = transaction.serialize()
        let serializedTags = serialized["tags"] as? [String: String]
        XCTAssertTrue(serializedTags?.isEmpty ?? true, "Serialized tags should be empty")
    }
    
    func testSerializeOrigin() throws {
        let scope = Scope()
        let transaction = fixture.getTransactionWith(scope: scope)
        let actual = transaction.serialize()
        
        let contexts = try XCTUnwrap(actual["contexts"] as? [String: Any])
        let traceContext = try XCTUnwrap(contexts["trace"] as? [String: Any])
        
        XCTAssertEqual(fixture.traceOrigin, traceContext["origin"] as? String)
    }

    func testSerialize_TransactionInfo() {
        let scope = Scope()
        let transaction = fixture.getTransactionWith(scope: scope)
        let actual = transaction.serialize()

        let actualTransactionInfo = actual["transaction_info"] as? [String: String]
        XCTAssertEqual(actualTransactionInfo?["source"], "component")
    }
    
    func testSerialize_TransactionName() {
        let scope = Scope()
        let transaction = fixture.getTransactionWith(scope: scope)
        let actual = transaction.serialize()

        let actualTransaction = actual["transaction"] as? String
        XCTAssertEqual(actualTransaction, fixture.transactionName)
    }
    
    func testSerializedSpanData() throws {
        let sut = fixture.getTransaction()
        let serialized = sut.serialize()
        let contexts = try XCTUnwrap(serialized["contexts"] as? [String: Any])
        let trace = try XCTUnwrap(contexts["trace"] as? [String: Any])
        let data = try XCTUnwrap(trace["data"] as? [String: Any])
        XCTAssertNotNil(try XCTUnwrap(data["thread.id"]))
        XCTAssertNotNil(try XCTUnwrap(data["thread.name"]))
    }
    
#if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
    func testTransactionWithContinuousProfile() throws {
        let options = Options()
        SentrySDK.setStart(with: options)
        let transaction = fixture.getTransaction()
        SentryContinuousProfiler.start()
        let profileId = try XCTUnwrap(SentryContinuousProfiler.profiler()?.profilerId.sentryIdString)
        let serialized = transaction.serialize()
        let contexts = try XCTUnwrap(serialized["contexts"] as? [String: Any])
        let profileData = try XCTUnwrap(contexts["profile"] as? [String: Any])
        let profileIdFromContexts = try XCTUnwrap(profileData["profiler_id"] as? String)
        XCTAssertEqual(profileId, profileIdFromContexts)
    }
#endif // os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
}
