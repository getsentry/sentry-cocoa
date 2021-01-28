import XCTest

class SentryTransactionTest: XCTestCase {
    let someTransactionName = "Some Transaction"
    
    func testInitWithName() {
        let transaction = SentryTransaction(name: someTransactionName)
        XCTAssertNotNil(transaction.startTimestamp)
        XCTAssertNil(transaction.timestamp)
        XCTAssertEqual(transaction.transaction, someTransactionName)
    }
    
    func testInitWithTransactionContext() {
        let context = TransactionContext(name: someTransactionName)
        let transaction = SentryTransaction(transactionContext: context, andHub: nil)
        XCTAssertNotNil(transaction.startTimestamp)
        XCTAssertNil(transaction.timestamp)
        XCTAssertEqual(transaction.transaction, someTransactionName)
    }
    
    func testInitWithNameAndContext() {
        let context = SpanContext()
        let transaction = SentryTransaction(name: someTransactionName, spanContext: context, andHub: nil)
        XCTAssertNotNil(transaction.startTimestamp)
        XCTAssertNil(transaction.timestamp)
        XCTAssertEqual(transaction.transaction, someTransactionName)
    }
    
    func testFinishCapturesTransaction() {
        let fileManager = try! SentryFileManager(dsn: TestConstants.dsn, andCurrentDateProvider: TestCurrentDateProvider())
        let transport = TestTransport()
        let client = TestClient(options: Options(), andTransport: transport, andFileManager: fileManager)
        let hub = SentryHub(client: client, andScope: nil, andCrashAdapter: TestSentryCrashWrapper())

        let transaction = SentryTransaction(name: someTransactionName, spanContext: SpanContext(), andHub: hub)
        transaction.finish()

        XCTAssertNotNil(transaction.startTimestamp)
        XCTAssertNotNil(transaction.timestamp)
        XCTAssertTrue(transaction.timestamp! >= transaction.startTimestamp!)
        XCTAssertTrue(client.captureEventWithScopeArguments.last!.event === transaction)
    }
    
    func testSerialization() {
        let transaction = SentryTransaction(name: someTransactionName)
        transaction.finish()
        
        let serialization = transaction.serialize()
        XCTAssertEqual(serialization["type"] as? String, "transaction")
        XCTAssertNotNil(serialization["event_id"])
        XCTAssertNotNil(serialization["start_timestamp"])
        XCTAssertNotNil(serialization["timestamp"])
        XCTAssertEqual(serialization["transaction"] as? String, someTransactionName)
        XCTAssertNotNil(serialization["contexts"])
    }
}
