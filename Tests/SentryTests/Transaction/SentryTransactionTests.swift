@testable import Sentry
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
        
        func getHub() -> SentryHub {
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
    
    func testSerialize_Tags() {
        // given
        let trace = fixture.getTrace()
        trace.setTag(value: fixture.testValue, key: fixture.testKey)
        
        let sut = Transaction(trace: trace, children: [])
        
        // when
        let serializedTransaction = sut.serialize()
        let serializedTransactionTags = try! XCTUnwrap(serializedTransaction["tags"] as? [String: String])
        
        // then
        XCTAssertEqual(serializedTransactionTags, [fixture.testKey: fixture.testValue])
    }
    
    func testSerialize_shouldPreserveTagsFromScope() {
        // given
        let scope = Scope()
        scope.setTag(value: fixture.testValue, key: fixture.testKey)
        let transaction = fixture.getTransactionWith(scope: scope)
        
        let sut = try! XCTUnwrap(scope.applyTo(event: transaction, maxBreadcrumbs: 0))

        // when
        let serializedTransaction = sut.serialize()
        let serializedTransactionTags = try! XCTUnwrap(serializedTransaction["tags"] as? [String: String])
        
        // then
        XCTAssertEqual(serializedTransactionTags, [fixture.testKey: fixture.testValue])
    }
    
    func testSerialize_shouldPreserveExtra() {
        // given
        let trace = fixture.getTrace()
        trace.setData(value: fixture.testValue, key: fixture.testKey)
        
        let sut = Transaction(trace: trace, children: [])
        
        // when
        let serializedTransaction = sut.serialize()
        let serializedTransactionExtra = try! XCTUnwrap(serializedTransaction["extra"] as? [String: Any])
        
        // then
        XCTAssertEqual(try XCTUnwrap(serializedTransactionExtra[fixture.testKey] as? String), fixture.testValue)
    }
    
    func testSerialize_shouldPreserveExtraFromScope() {
        // given
        let scope = Scope()
        scope.setExtra(value: fixture.testValue, key: fixture.testKey)
        
        let transaction = fixture.getTransactionWith(scope: scope)
        
        let sut = try! XCTUnwrap(scope.applyTo(event: transaction, maxBreadcrumbs: 0))

        // when
        let serializedTransaction = sut.serialize()
        let serializedTransactionExtra = try! XCTUnwrap(serializedTransaction["extra"] as? [String: Any])
        
        // then
        XCTAssertEqual(try XCTUnwrap(serializedTransactionExtra[fixture.testKey] as? String), fixture.testValue)
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
    
    func testSerializeMetricsSummary() throws {
        let sut = fixture.getTransaction()
        let aggregator = sut.trace.getLocalMetricsAggregator()
        aggregator.add(type: .counter, key: "key", value: 1.0, unit: .none, tags: [:])
        
        let serialized = sut.serialize()
        
        let metricsSummary = try XCTUnwrap(serialized["_metrics_summary"] as? [String: [[String: Any]]])
        XCTAssertEqual(metricsSummary.count, 1)
        
        let bucket = try XCTUnwrap(metricsSummary["c:key"])
        XCTAssertEqual(bucket.count, 1)
        let metric = try XCTUnwrap(bucket.first)
        XCTAssertEqual(metric["min"] as? Double, 1.0)
        XCTAssertEqual(metric["max"] as? Double, 1.0)
        XCTAssertEqual(metric["count"] as? Int, 1)
        XCTAssertEqual(metric["sum"] as? Double, 1.0)
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
        SentrySDK.setStart(Options())
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
