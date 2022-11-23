import XCTest

class SentryTransactionTests: XCTestCase {
    
    private class Fixture {
        let transactionName = "Some Transaction"
        let transactionOperation = "ui.load"
        let testKey = "extra_key"
        let testValue = "extra_value"
        
        func getTransaction(trace: SentryTracer = SentryTracer(transactionContext: TransactionContext(operation: "operation"), hub: TestHub(client: nil, andScope: nil))) -> Transaction {
            return Transaction(trace: trace, children: [])
        }
        
        func getContext() -> TransactionContext {
            return TransactionContext(name: transactionName, nameSource: .component, operation: transactionOperation)
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
        XCTAssertEqual(value, coldStartMeasurement?["value"] as! NSNumber)
        XCTAssertEqual(unit.unit, coldStartMeasurement?["unit"] as! String)
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
        XCTAssertEqual(frameValue, frameMeasurement?["value"] as! NSNumber)
        XCTAssertNil(frameMeasurement?["unit"])
        
        let customMeasurement = actualMeasurements?[customName]
        XCTAssertEqual(customValue, customMeasurement?["value"] as! NSNumber)
        XCTAssertEqual(customUnit.unit, customMeasurement?["unit"] as! String)
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
        let serializedTransactionExtra = try! XCTUnwrap(serializedTransaction["extra"] as? [String: String])
        
        // then
        XCTAssertEqual(serializedTransactionExtra, [fixture.testKey: fixture.testValue])
    }
    
    func testSerialize_shouldPreserveExtraFromScope() {
        // given
        let scope = Scope()
        scope.setExtra(value: fixture.testValue, key: fixture.testKey)
        
        let transaction = fixture.getTransactionWith(scope: scope)
        
        let sut = try! XCTUnwrap(scope.applyTo(event: transaction, maxBreadcrumbs: 0))

        // when
        let serializedTransaction = sut.serialize()
        let serializedTransactionExtra = try! XCTUnwrap(serializedTransaction["extra"] as? [String: String])
        
        // then
        XCTAssertEqual(serializedTransactionExtra, [fixture.testKey: fixture.testValue])
    }

    func testSerialize_TransactionInfo() {
        let scope = Scope()
        let transaction = fixture.getTransactionWith(scope: scope)
        let actual = transaction.serialize()

        let actualTransactionInfo = actual["transaction_info"] as? [String: String]
        XCTAssertEqual(actualTransactionInfo?["source"], "component")
    }
}
