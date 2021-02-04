import XCTest

class SentrySpanTests: XCTestCase {
    
    private class Fixture {
        let someTransaction = "Some Transaction"
        let someOperation = "Some Operation"
        let someDescription = "Some Description"
        let extraKey = "extra_key"
        let extraValue = "extra_value"
        
        func getSut() -> Span {
            let transaction = Transaction(name: someTransaction)
            return Span(transaction: transaction, trace: SentryId(), andParentId: transaction.spanId)
        }
    }
    
    private var fixture: Fixture!
    override func setUp() {
        fixture = Fixture();
    }
    
    func testInitAndCheckForTimestamps() {
        let span = fixture.getSut()
        XCTAssertNotNil(span.startTimestamp)
        XCTAssertNil(span.timestamp)
    }
    
    func testFinish() {
        let span = fixture.getSut()
        span.finish()
        XCTAssertNotNil(span.timestamp)
        XCTAssertTrue(span.isFinished)
    }
    
    func testFinishWithStatus() {
        let span = fixture.getSut()
        span.finish(status: .ok)
        XCTAssertNotNil(span.timestamp)
        XCTAssertEqual(span.status, .ok)
        XCTAssertTrue(span.isFinished)
    }
    
    func testStartChildWithOperation() {
        let span = fixture.getSut()
        
        let childSpan = span.startChild(operation: fixture.someOperation)
        XCTAssertEqual(childSpan.parentSpanId, span.spanId)
        XCTAssertEqual(childSpan.operation, fixture.someOperation)
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

        span.setExtra(fixture.extraKey, withValue: fixture.extraValue)
        
        XCTAssertEqual(span.extras!.count, 1)
        XCTAssertEqual(span.extras![fixture.extraKey] as! String, fixture.extraValue)
    }
    
    func testSerialization() {
        let span = fixture.getSut()
        
        span.setExtra(fixture.extraKey, withValue: fixture.extraValue)
        span.finish()
                
        let serialization = span.serialize()
        XCTAssertNotNil(serialization["timestamp"])
        XCTAssertNotNil(serialization["start_timestamp"])
        XCTAssertNotNil(serialization["data"])
        XCTAssertEqual((serialization["data"] as! Dictionary)[fixture.extraKey], fixture.extraValue)
    }
}
