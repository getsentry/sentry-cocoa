import XCTest

class SentrySpanTests: XCTestCase {
    private class Fixture {
        let someTransaction = "Some Transaction"
        let someOperation = "Some Operation"
        let someDescription = "Some Description"
        let extraKey = "extra_key"
        let extraValue = "extra_value"
        let options: Options
        let currentDateProvider = TestCurrentDateProvider()
         
        init() {
            options = Options()
            options.tracesSampleRate = 1
            options.dsn = TestConstants.dsnAsString(username: "username")
            options.environment = "test"
            currentDateProvider.setDate(date: TestData.timestamp)
        }
        
        func getSut() -> Span {
            return getSut(client: TestClient(options: options)!)
        }
        
        func getSut(client: Client) -> Span {
            let hub = SentryHub(client: client, andScope: nil, andCrashAdapter: TestSentryCrashAdapter.sharedInstance(), andCurrentDateProvider: currentDateProvider)
            return hub.startTransaction(name: someTransaction, operation: someOperation)
        }
        
    }
    
    private var fixture: Fixture!
    override func setUp() {
        super.setUp()
        fixture = Fixture()
        CurrentDate.setCurrentDateProvider(fixture.currentDateProvider)
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
        let childSpan = span.startChild(operation: fixture.someOperation)
        
        childSpan.finish()
        span.finish()
        
        let lastEvent = client.captureEventWithScopeArguments[0].event
        let serializedData = lastEvent.serialize()
        
        let spans = serializedData["spans"] as! [Any]
        let serializedChild = spans[0] as! [String: Any]
        
        XCTAssertEqual(serializedChild["span_id"] as? String, childSpan.context.spanId.sentrySpanIdString)
        XCTAssertEqual(serializedChild["parent_span_id"] as? String, span.context.spanId.sentrySpanIdString)
    }
    
    func testFinishWithUnfinishedSpanDropsSpan() {
        let client = TestClient(options: fixture.options)!
        let span = fixture.getSut(client: client)
        span.startChild(operation: fixture.someOperation)
        
        span.finish()
        let lastEvent = client.captureEventWithScopeArguments[0].event
        let serializedData = lastEvent.serialize()
        
        let spans = serializedData["spans"] as! [Any]
        
        XCTAssertEqual(spans.count, 0)
    }
    
    func testStartChildWithNameOperation() {
        let span = fixture.getSut()
        
        let childSpan = span.startChild(operation: fixture.someOperation)
        XCTAssertEqual(childSpan.context.parentSpanId, span.context.spanId)
        XCTAssertEqual(childSpan.context.operation, fixture.someOperation)
        XCTAssertNil(childSpan.context.spanDescription)
    }
    
    func testStartChildWithNameOperationAndDescription() {
        let span = fixture.getSut()
        
        let childSpan = span.startChild(operation: fixture.someOperation, description: fixture.someDescription)
        
        XCTAssertEqual(childSpan.context.parentSpanId, span.context.spanId)
        XCTAssertEqual(childSpan.context.operation, fixture.someOperation)
        XCTAssertEqual(childSpan.context.spanDescription, fixture.someDescription)
    }
    
    func testAddAndRemoveExtras() {
        let span = fixture.getSut()

        span.setExtra(value: fixture.extraValue, key: fixture.extraKey)
        
        XCTAssertEqual(span.data!.count, 1)
        XCTAssertEqual(span.data![fixture.extraKey] as! String, fixture.extraValue)
        
        span.removeData(key: fixture.extraKey)
        XCTAssertEqual(span.data!.count, 0)
        XCTAssertNil(span.data![fixture.extraKey])
    }
    
    func testAddAndRemoveTags() {
        let span = fixture.getSut()
        
        span.setTag(value: fixture.extraValue, key: fixture.extraKey)
        
        XCTAssertEqual(span.tags.count, 1)
        XCTAssertEqual(span.tags[fixture.extraKey], fixture.extraValue)
        
        span.removeTag(key: fixture.extraKey)
        XCTAssertEqual(span.tags.count, 0)
        XCTAssertNil(span.tags[fixture.extraKey])
    }
    
    func testSerialization() {
        let span = fixture.getSut()
        
        span.setExtra(value: fixture.extraValue, key: fixture.extraKey)
        span.setTag(value: fixture.extraValue, key: fixture.extraKey)
        span.finish()
        
        let serialization = span.serialize()
        XCTAssertEqual(serialization["span_id"] as? String, span.context.spanId.sentrySpanIdString)
        XCTAssertEqual(serialization["trace_id"] as? String, span.context.traceId.sentryIdString)
        XCTAssertEqual(serialization["timestamp"] as? TimeInterval, TestData.timestamp.timeIntervalSince1970)
        XCTAssertEqual(serialization["start_timestamp"] as? TimeInterval, TestData.timestamp.timeIntervalSince1970)
        XCTAssertEqual(serialization["type"] as? String, SpanContext.type)
        XCTAssertEqual(serialization["sampled"] as? String, "true")
        XCTAssertNotNil(serialization["data"])
        XCTAssertNotNil(serialization["tags"])
        XCTAssertEqual((serialization["data"] as! Dictionary)[fixture.extraKey], fixture.extraValue)
        XCTAssertEqual((serialization["tags"] as! Dictionary)[fixture.extraKey], fixture.extraValue)
    }
    
    func testSerialization_WithNoDataAndTag() {
        let span = fixture.getSut()
        
        let serialization = span.serialize()
        XCTAssertNil(serialization["data"])
        XCTAssertNil(serialization["tag"])
    }
    
    func testMergeTagsInSerialization() {
        let context = SpanContext(operation: fixture.someOperation)
        context.setTag(value: fixture.someTransaction, key: fixture.extraKey)
        let span = SentrySpan(context: context)
        
        let originalSerialization = span.serialize()
        XCTAssertEqual((originalSerialization["tags"] as! Dictionary)[fixture.extraKey], fixture.someTransaction)
        
        span.setTag(value: fixture.extraValue, key: fixture.extraKey)
        
        let mergedSerialization = span.serialize()
        XCTAssertEqual((mergedSerialization["tags"] as! Dictionary)[fixture.extraKey], fixture.extraValue)
    }
    
    func testTraceHeaderNotSampled() {
        fixture.options.tracesSampleRate = 0
        let span = fixture.getSut()
        let header = span.toTraceHeader()
        
        XCTAssertEqual(header.traceId, span.context.traceId)
        XCTAssertEqual(header.spanId, span.context.spanId)
        XCTAssertEqual(header.sampled, .no)
        XCTAssertEqual(header.value(), "\(span.context.traceId)-\(span.context.spanId)-0")
    }
    
    func testTraceHeaderSampled() {
        let span = SentrySpan(context: SpanContext(operation: fixture.someOperation, sampled: .yes))
        let header = span.toTraceHeader()
        
        XCTAssertEqual(header.traceId, span.context.traceId)
        XCTAssertEqual(header.spanId, span.context.spanId)
        XCTAssertEqual(header.sampled, .yes)
        XCTAssertEqual(header.value(), "\(span.context.traceId)-\(span.context.spanId)-1")
    }
    
    func testTraceHeaderUndecided() {
        let span = SentrySpan(context: SpanContext(operation: fixture.someOperation, sampled: .undecided))
        let header = span.toTraceHeader()
        
        XCTAssertEqual(header.traceId, span.context.traceId)
        XCTAssertEqual(header.spanId, span.context.spanId)
        XCTAssertEqual(header.sampled, .undecided)
        XCTAssertEqual(header.value(), "\(span.context.traceId)-\(span.context.spanId)")
    }
    
    func testSetExtra_ForwardsToSetData() {
        let sut = SentrySpan(context: SpanContext(operation: "test"))
        sut.setExtra(value: 0, key: "key")
        
        XCTAssertEqual(["key": 0], sut.data as! [String: Int])
    }
    
    @available(tvOS 10.0, *)
    @available(OSX 10.12, *)
    @available(iOS 10.0, *)
    func testModifyingExtraFromMultipleThreads() {
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
                    span.setTag(value: value, key: "\(i)-\(j)")
                }
                
                group.leave()
            }
        }
        
        queue.activate()
        group.wait()
        XCTAssertEqual(span.data!.count, outerLoop * innerLoop)
    }
}
