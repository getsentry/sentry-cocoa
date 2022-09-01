import XCTest

class SentryTransactionTests: XCTestCase {
    
    private class Fixture {
        let transactionName = "Some Transaction"
        let transactionOperation = "ui.load"
        let testKey = "extra_key"
        let testValue = "extra_value"
        
        func getTransaction() -> Transaction {
            return Transaction(trace: SentryTracer(), children: [])
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
    
    func testSerializeMeasurements_Measurements() {
        let transaction = fixture.getTransaction()
        
        let appStart = ["value": 15_000.0]
        transaction.setMeasurementValue(appStart, forKey: "app_start_cold")
        let actual = transaction.serialize()
        
        let actualMeasurements = actual["measurements"] as? [String: [String: Double]]
        XCTAssertEqual(appStart, actualMeasurements?["app_start_cold"] )
    }

    func testSerializeMeasurements_GarbageInMeasurements_GarbageSanitized() {
        let transaction = fixture.getTransaction()
        
        let appStart = ["value": self]
        transaction.setMeasurementValue(appStart, forKey: "app_start_cold")
        let actual = transaction.serialize()
        
        let actualMeasurements = actual["measurements"] as? [String: [String: String]]
        XCTAssertEqual(["value": self.description], actualMeasurements?["app_start_cold"] )
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
    
    func testSerialize_shouldPreserveTagsFromContext() {
        // given
        let context = TransactionContext(name: fixture.transactionName, operation: fixture.transactionOperation)
        context.setTag(value: fixture.testValue, key: fixture.testKey)
        let trace = SentryTracer(transactionContext: context, hub: fixture.getHub())
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
        
        let sut = try! XCTUnwrap(scope.apply(to: transaction, maxBreadcrumb: 0))

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
        
        let sut = try! XCTUnwrap(scope.apply(to: transaction, maxBreadcrumb: 0))

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
