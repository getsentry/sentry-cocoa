import XCTest

class SentrySpanTests: XCTestCase {
    
    private class Fixture {
        let someTransaction = "Some Transaction"
        let someOperation = "Some Operation"
        let someDescription = "Some Description"
        let extraKey = "extra_key"
        let extraValue = "extra_value"
        
        func getSut() -> Span {
            let transaction = Transaction(name: someTransaction, operation: someOperation)
            return Span(transaction: transaction, operation: someOperation, trace: SentryId(), parentId: transaction.spanId)
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
        let span = fixture.getSut()
        
        span.finish()
        
        XCTAssertEqual(span.startTimestamp, TestData.timestamp)
        XCTAssertEqual(span.timestamp, TestData.timestamp)
        XCTAssertTrue(span.isFinished)
    }
    
    func testFinishWithStatus() {
        let span = fixture.getSut()
        span.finish(status: .ok)
        
        XCTAssertEqual(span.startTimestamp, TestData.timestamp)
        XCTAssertEqual(span.timestamp, TestData.timestamp)
        XCTAssertEqual(span.status, .ok)
        XCTAssertTrue(span.isFinished)
    }
    
    func testStartChildWithOperation() {
        let span = fixture.getSut()
        
        let childSpan = span.startChild(operation: fixture.someOperation)
        XCTAssertEqual(childSpan.parentSpanId, span.spanId)
        XCTAssertEqual(childSpan.operation, fixture.someOperation)
        XCTAssertNil(childSpan.spanDescription)
    }
    
    func testStartChildWithOperationAndDescription() {
        let span = fixture.getSut()
        
        let childSpan = span.startChild(operation: fixture.someOperation, description: fixture.someDescription)
        
        XCTAssertEqual(childSpan.parentSpanId, span.spanId)
        XCTAssertEqual(childSpan.operation, fixture.someOperation)
        XCTAssertEqual(childSpan.spanDescription, fixture.someDescription)
    }
    
    func testSetExtras() {
        let span = fixture.getSut()

        span.setExtra(value: fixture.extraValue, key: fixture.extraKey)
        
        XCTAssertEqual(span.extras!.count, 1)
        XCTAssertEqual(span.extras![fixture.extraKey] as! String, fixture.extraValue)
    }
    
    func testSerialization() {
        let span = fixture.getSut()
        
        span.setExtra(value: fixture.extraValue, key: fixture.extraKey)
        span.finish()
                
        let serialization = span.serialize()
        XCTAssertEqual(serialization["timestamp"] as? String, TestData.timestampAs8601String)
        XCTAssertEqual(serialization["start_timestamp"] as? String, TestData.timestampAs8601String)
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
        XCTAssertEqual(span.extras!.count, outerLoop * innerLoop)
    }
}
