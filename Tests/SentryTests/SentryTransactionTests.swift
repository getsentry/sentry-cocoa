import XCTest

class SentryTransactionTest: XCTestCase {
    let someTransactionName = "Some Transaction"
    
    func testInitWithName() {
        let transaction = Transaction(name: someTransactionName)
        XCTAssertNotNil(transaction.startTimestamp)
        XCTAssertNil(transaction.timestamp)
        XCTAssertEqual(transaction.transaction, someTransactionName)
    }
    
    func testInitWithTransactionContext() {
        let context = TransactionContext(name: someTransactionName)
        let transaction = Transaction(transactionContext: context, andHub: nil)
        XCTAssertNotNil(transaction.startTimestamp)
        XCTAssertNil(transaction.timestamp)
        XCTAssertEqual(transaction.transaction, someTransactionName)
    }
    
    func testInitWithNameAndContext() {
        let context = SpanContext()
        let transaction = Transaction(name: someTransactionName, context: context, andHub: nil)
        XCTAssertNotNil(transaction.startTimestamp)
        XCTAssertNil(transaction.timestamp)
        XCTAssertEqual(transaction.transaction, someTransactionName)
    }
    
    func testFinishCapturesTransaction() {
        let fileManager = try! SentryFileManager(dsn: TestConstants.dsn, andCurrentDateProvider: TestCurrentDateProvider())
        let transport = TestTransport()
        let client = TestClient(options: Options(), andTransport: transport, andFileManager: fileManager)
        let hub = SentryHub(client: client, andScope: nil, andCrashAdapter: TestSentryCrashWrapper())

        let transaction = Transaction(name: someTransactionName, context: SpanContext(), andHub: hub)
        transaction.finish()

        XCTAssertNotNil(transaction.startTimestamp)
        XCTAssertNotNil(transaction.timestamp)
        XCTAssertTrue(transaction.timestamp! >= transaction.startTimestamp!)
        XCTAssertTrue(client.captureEventWithScopeArguments.last!.event === transaction)
    }
    
    func testSerialization() {
        let transaction = Transaction(name: someTransactionName)
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
