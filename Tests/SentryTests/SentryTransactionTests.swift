import XCTest

class SentryTransactionTest: XCTestCase {
    let someTransactionName = "Some Transaction"
    let someOperation = "Some Operation"
    
    func testInitWithName() {
        let transaction = Transaction(name: someTransactionName)
        
        XCTAssertNotNil(transaction.startTimestamp)
        XCTAssertNil(transaction.timestamp)
        XCTAssertEqual(transaction.transaction, someTransactionName)
    }
    
    func testInitWithTransactionContext() {
        let someOperation = "Some Operation"
        let someSpanDescription = "Some Span Description"
        
        let context = TransactionContext(name: someTransactionName, trace: SentryId(), spanId: SpanId(), parentSpanId: SpanId(), andParentSampled: true)
        context.operation = someOperation
        context.status = .ok
        context.sampled = true
        context.spanDescription = someSpanDescription
        
        let transaction = Transaction(transactionContext: context, hub: nil)
        XCTAssertNotNil(transaction.startTimestamp)
        XCTAssertNil(transaction.timestamp)
        XCTAssertEqual(transaction.transaction, someTransactionName)
        XCTAssertEqual(transaction.traceId, context.traceId)
        XCTAssertEqual(transaction.spanId, context.spanId)
        XCTAssertEqual(transaction.operation, someOperation)
        XCTAssertEqual(transaction.status, SentrySpanStatus.ok)
        XCTAssertTrue(transaction.isSampled)
        XCTAssertEqual(transaction.spanDescription, someSpanDescription)
    }
    
    func testIndirectManipulationOfContext() {
        let someOperation = "Some Operation"
        let spanDescription = "Span Description"
        
        let context = TransactionContext(name: someTransactionName)
        
        let transaction = Transaction(transactionContext: context, hub: nil)
        transaction.spanDescription = spanDescription
        transaction.operation = someOperation
        transaction.status = .ok
        
        XCTAssertEqual(context.spanDescription, spanDescription)
        XCTAssertEqual(context.operation, someOperation)
        XCTAssertEqual(context.status, SentrySpanStatus.ok)
    }
    
    func testInitWithNameAndContext() {
        let context = SpanContext()
        context.operation = someOperation
        context.status = .ok

        let transaction = Transaction(name: someTransactionName, spanContext: context, hub: nil)
        XCTAssertNotNil(transaction.startTimestamp)
        XCTAssertNil(transaction.timestamp)
        XCTAssertEqual(transaction.transaction, someTransactionName)
        XCTAssertEqual(transaction.traceId, context.traceId)
        XCTAssertEqual(transaction.spanId, context.spanId)
        XCTAssertEqual(transaction.operation, someOperation)
        XCTAssertEqual(transaction.status, SentrySpanStatus.ok)
    }
    
    func testFinishCapturesTransaction() {
        let fileManager = try! SentryFileManager(dsn: TestConstants.dsn, andCurrentDateProvider: TestCurrentDateProvider())
        let transport = TestTransport()
        let client = TestClient(options: Options(), andTransport: transport, andFileManager: fileManager)
        let hub = SentryHub(client: client, andScope: nil, andCrashAdapter: TestSentryCrashWrapper())

        let transaction = Transaction(name: someTransactionName, spanContext: SpanContext(), hub: hub)
        transaction.finish()

        XCTAssertNotNil(transaction.startTimestamp)
        XCTAssertNotNil(transaction.timestamp)
        XCTAssertTrue(transaction.timestamp! >= transaction.startTimestamp!)
        XCTAssertTrue(client.captureEventWithScopeArguments.last!.event === transaction)
    }

    func testSerializationWithoutContext() {
        let transaction = Transaction(name: someTransactionName)
        
        let serialization = transaction.serialize()
        XCTAssertNotNil(serialization)
        XCTAssertEqual(serialization["type"] as? String, "transaction")
        XCTAssertNotNil(serialization["event_id"])
        XCTAssertNotNil(serialization["start_timestamp"])
        XCTAssertNotNil(serialization["timestamp"])
        XCTAssertEqual(serialization["transaction"] as? String, someTransactionName)
        XCTAssertNotNil(serialization["contexts"])
        XCTAssertNotNil((serialization["contexts"] as! Dictionary)["trace"])
        XCTAssertNotNil(serialization["spans"])
    }
    
    func testSerializationWithContext() {
        let transaction = Transaction(name: someTransactionName)
        transaction.context = [String: [String: Any]]()
        
        let serialization = transaction.serialize()
        XCTAssertNotNil(serialization)
        XCTAssertEqual(serialization["type"] as? String, "transaction")
        XCTAssertNotNil(serialization["event_id"])
        XCTAssertNotNil(serialization["start_timestamp"])
        XCTAssertNotNil(serialization["timestamp"])
        XCTAssertEqual(serialization["transaction"] as? String, someTransactionName)
        XCTAssertNotNil(serialization["contexts"])
        XCTAssertNotNil((serialization["contexts"] as! Dictionary)["trace"])
        XCTAssertNotNil(serialization["spans"])
    }
    
    func testAdditionOfChild() {
        let transaction = Transaction(name: someTransactionName)
        transaction.startChild(operation: someOperation)
        XCTAssertEqual(transaction.spans.count, 1)
    }
    
    func testSerializeWithSpan() {
        let transaction = Transaction(name: someTransactionName)
        transaction.startChild(operation: someOperation)
        
        let serialization = transaction.serialize()
        let spansSerialized = serialization["spans"] as! Dictionary<String, Any>
        XCTAssertEqual(spansSerialized.count, 1)
    }
    
    func testAddChildWithOperation() {
        let transaction = Transaction(name: someTransactionName)
        let span = transaction.startChild(operation: someOperation)
        XCTAssertEqual(span.operation, someOperation)
    }
    
    func testAddChildWithOperationAndDescription() {
        let transaction = Transaction(name: someTransactionName)
        let someDescription = "Some Description"
        let span = transaction.startChild(operation: someOperation, description: someDescription)
        
        XCTAssertEqual(span.operation, someOperation)
        XCTAssertEqual(span.spanDescription, someDescription)
    }
}
