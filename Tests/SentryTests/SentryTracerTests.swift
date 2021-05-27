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
    
    func testSpanHierarchy() {
        let tracer = fixture.getSut()
        let child = tracer.startChild(operation: fixture.transactionOperation)
        let grandChild = child.startChild(operation: fixture.transactionOperation)
        
        let tracerSpans = Dynamic(tracer).spans.asArray!
        let childSpan = Dynamic(child).spans.asArray!
        
        XCTAssertTrue(tracerSpans.contains(child))
        XCTAssertTrue(childSpan.contains(grandChild))
        XCTAssertFalse(tracerSpans.contains(grandChild))
        
        XCTAssertEqual(tracerSpans.count, 1)
        XCTAssertEqual(childSpan.count, 1)
    }
    
    func testSpanFlatList() {
        let tracer = fixture.getSut()
        let child = tracer.startChild(operation: fixture.transactionOperation)
        let grandChild = child.startChild(operation: fixture.transactionOperation)
        
        let tracerChildren = Dynamic(tracer).children.asArray!
        let childChildren = Dynamic(child).children.asArray!
        
        XCTAssertTrue(tracerChildren.contains(child))
        XCTAssertTrue(tracerChildren.contains(grandChild))
        XCTAssertFalse(childChildren.contains(child))
        
        XCTAssertEqual(tracerChildren.count, 2)
        XCTAssertEqual(childChildren.count, 1)
        
    }
    
}
