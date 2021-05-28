import XCTest

class SentryTracerTests: XCTestCase {
    private class Fixture {
        
        let transactionName = "Some Transaction"
        let transactionOperation = "Some Operation"
        var transactionContext: TransactionContext!
        
        init() {
            transactionContext = TransactionContext(name: transactionName, operation: transactionOperation)
        }
        
        func getSut(waitForChildren: Bool = true) -> SentryTracer {
            return SentryTracer(transactionContext: transactionContext, hub: nil, waitForChildren: waitForChildren)
        }
        
    }
    
    private var fixture: Fixture!
    
    override func setUp() {
        fixture = Fixture()
    }
    
    func testTracerWaitingForChildren() {
        let tracer = fixture.getSut()
        let child = tracer.startChild(operation: fixture.transactionOperation)
        tracer.finish()
        XCTAssertFalse(tracer.isFinished)

        let grandChild = child.startChild(operation: fixture.transactionOperation)
        child.finish()
        
        XCTAssertFalse(tracer.isFinished)

        let granGrandChild = grandChild.startChild(operation: fixture.transactionOperation)
        
        granGrandChild.finish()
        grandChild.finish()
        
        XCTAssertTrue(tracer.isFinished)
        
        let transaction : Transaction? = Dynamic(tracer).toTransaction()
        let serialization : [String: Any] = transaction!.serialize()
        let spans = serialization["spans"]! as! Array<[String: Any]>
        
        let tracerTimestamp :NSDate = tracer.timestamp! as NSDate
        
        XCTAssertEqual(spans.count, 3)
        XCTAssertEqual(tracerTimestamp.sentry_toIso8601String(), serialization["timestamp"]! as! String)
    }
    
}
