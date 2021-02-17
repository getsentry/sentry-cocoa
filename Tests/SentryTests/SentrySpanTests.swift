import XCTest

class SentrySpanTests: XCTestCase {
    private class Fixture {
        let someTransaction = "Some Transaction"
        let someOperation = "Some Operation"
        let someDescription = "Some Description"
        let extraKey = "extra_key"
        let extraValue = "extra_value"
        let spanName = "Span Name"
        let options: Options
        
        init() {
            options = Options()
            options.dsn = TestConstants.dsnAsString
            options.environment = "test"
        }
        
        func getSut() -> Span {
            return getSut(client: TestClient(options: options)!)
        }
        
        func getSut(client: Client) -> Span {
            let hub = SentryHub(client: client, andScope: nil, andCrashAdapter: TestSentryCrashWrapper())
            return hub.startTransaction(name: someTransaction, operation: someOperation)
        }
        
    }
    
    private var fixture: Fixture!
    override func setUp() {
        let testDataProvider = TestCurrentDateProvider()
        CurrentDate.setCurrentDateProvider(testDataProvider)
        testDataProvider.setDate(date: TestData.timestamp)
        
        fixture = Fixture()
    }
    
    func testInitAndCheckForTimestamps() {
        let span = fixture.getSut()
        XCTAssertNotNil(span.startTimestamp)
        XCTAssertNil(span.timestamp)
        XCTAssertFalse(span.isFinished)
    }
    
    func testFinish() {
        let client = TestClient(options: fixture.options)!
        let span = fixture.getSut(client: client)
        
        span.finish()
        
        XCTAssertEqual(span.startTimestamp, TestData.timestamp)
        XCTAssertEqual(span.timestamp, TestData.timestamp)
        XCTAssertTrue(span.isFinished)
        
        let lastEvent = client.captureEventWithScopeArguments[0].event
        XCTAssertEqual(lastEvent.transaction, fixture.someTransaction)
        XCTAssertEqual(lastEvent.timestamp, TestData.timestamp)
        XCTAssertEqual(lastEvent.startTimestamp, TestData.timestamp)
        XCTAssertEqual(lastEvent.type, SentryEnvelopeItemTypeTransaction)
        
    }
    
    func testFinishWithStatus() {
        let span = fixture.getSut()
        span.finish(status: .ok)
        
        XCTAssertEqual(span.startTimestamp, TestData.timestamp)
        XCTAssertEqual(span.timestamp, TestData.timestamp)
        XCTAssertEqual(span.context.status, .ok)
        XCTAssertTrue(span.isFinished)
    }
    
    func testFinishWithChild() {
        let client = TestClient(options: fixture.options)!
        let span = fixture.getSut(client: client)
        let childSpan = span.startChild(name: fixture.spanName, operation: fixture.someOperation)
        
        span.finish()
        let lastEvent = client.captureEventWithScopeArguments[0].event
        let serializedData = lastEvent.serialize()
        
        let spans = serializedData["spans"] as! [Any]
        let serializedChild = spans[0] as! [String: Any]
        
        XCTAssertEqual(serializedChild["span_id"] as? String, childSpan.context.spanId.sentrySpanIdString)
        XCTAssertEqual(serializedChild["parent_span_id"] as? String, span.context.spanId.sentrySpanIdString)
    }
    
    func testStartChildWithNameOperation() {
        let span = fixture.getSut()
        
        let childSpan = span.startChild(name: fixture.spanName, operation: fixture.someOperation)
        XCTAssertEqual(childSpan.context.parentSpanId, span.context.spanId)
        XCTAssertEqual(childSpan.context.operation, fixture.someOperation)
        XCTAssertNil(childSpan.context.spanDescription)
    }
    
    func testStartChildWithNameOperationAndDescription() {
        let span = fixture.getSut()
        
        let childSpan = span.startChild(name: fixture.spanName, operation: fixture.someOperation, description: fixture.someDescription)
        
        XCTAssertEqual(childSpan.context.parentSpanId, span.context.spanId)
        XCTAssertEqual(childSpan.context.operation, fixture.someOperation)
        XCTAssertEqual(childSpan.context.spanDescription, fixture.someDescription)
    }
    
    func testSetExtras() {
        let span = fixture.getSut()

        span.setExtra(value: fixture.extraValue, key: fixture.extraKey)
        
        XCTAssertEqual(span.data!.count, 1)
        XCTAssertEqual(span.data![fixture.extraKey] as! String, fixture.extraValue)
    }
    
    func testSerialization() {
        let span = fixture.getSut()
        
        span.setExtra(value: fixture.extraValue, key: fixture.extraKey)
        span.finish()
        
        let serialization = span.serialize()
        XCTAssertEqual(serialization["span_id"] as? String, span.context.spanId.sentrySpanIdString)
        XCTAssertEqual(serialization["trace_id"] as? String, span.context.traceId.sentryIdString)
        XCTAssertEqual(serialization["timestamp"] as? String, TestData.timestampAs8601String)
        XCTAssertEqual(serialization["start_timestamp"] as? String, TestData.timestampAs8601String)
        XCTAssertEqual(serialization["type"] as? String, SpanContext.type)
        XCTAssertEqual(serialization["sampled"] as? String, "false")
        XCTAssertNotNil(serialization["data"])
        XCTAssertEqual((serialization["data"] as! Dictionary)[fixture.extraKey], fixture.extraValue)
    }
    
    @available(tvOS 10.0, *)
    @available(OSX 10.12, *)
    @available(iOS 10.0, *)
    func testModifyingTagsFromMultipleThreads() {
        let queue = DispatchQueue(label: "SentrySpanTests", qos: .userInteractive, attributes: [.concurrent, .initiallyInactive])
        let group = DispatchGroup()
                
        let span = fixture.getSut()
        
        // The number is kept small for the CI to not take to long.
        // If you really want to test this increase to 100_000 or so.
        let innerLoop = 1_000
        let outerLoop = 20
        let value = fixture.extraValue
        
        for i in 0..<outerLoop {
            group.enter()
            queue.async {
                
                for j in 0..<innerLoop {
                    span.setExtra(value: value, key: "\(i)-\(j)")
                }
                
                group.leave()
            }
        }
        
        queue.activate()
        group.wait()
        XCTAssertEqual(span.data!.count, outerLoop * innerLoop)
    }
}
