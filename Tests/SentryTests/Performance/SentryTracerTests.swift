import XCTest

class SentryTracerTests: XCTestCase {
    
    private class Fixture {
        let client: TestClient
        let hub: TestHub
        let scope: Scope
        
        let transactionName = "Some Transaction"
        let transactionOperation = "Some Operation"
        var transactionContext: TransactionContext!
        
        let currentDateProvider = TestCurrentDateProvider()
        
        init() {
            transactionContext = TransactionContext(name: transactionName, operation: transactionOperation)
            
            scope = Scope()
            client = TestClient(options: Options())!
            hub = TestHub(client: client, andScope: scope)
            
            CurrentDate.setCurrentDateProvider(currentDateProvider)
        }
        
        func getSut(waitForChildren: Bool = true) -> SentryTracer {
            return SentryTracer(transactionContext: transactionContext, hub: hub, waitForChildren: waitForChildren)
        }
        
    }
    
    private var fixture: Fixture!
    
    override func setUp() {
        fixture = Fixture()
    }
    
    func testFinish_WithChildren_WaitsForAllChildren_finishParentFirst() {
        let sut = fixture.getSut()
        let child = sut.startChild(operation: fixture.transactionOperation)
        sut.finish()
        
        assertTransactionNotCaptured(sut)

        let grandChild = child.startChild(operation: fixture.transactionOperation)
        child.finish()
        
        assertTransactionNotCaptured(sut)

        let granGrandChild = grandChild.startChild(operation: fixture.transactionOperation)
        
        granGrandChild.finish()
        assertTransactionNotCaptured(sut)
        
        grandChild.finish()
        
        assertOneTransactionCaptured(sut)
        
        let serialization = getSerializedTransaction()
        let spans = serialization["spans"]! as! [[String: Any]]
        
        let tracerTimestamp: NSDate = sut.timestamp! as NSDate
        
        XCTAssertEqual(spans.count, 3)
        XCTAssertEqual(tracerTimestamp.sentry_toIso8601String(), serialization["timestamp"]! as! String)
        
        for span in spans {
            XCTAssertEqual(tracerTimestamp.sentry_toIso8601String(), span["timestamp"] as! String)
        }
    }
    
    func testFinish_WithChildren_WaitsForAllChildren_finishParentLast() {
        let sut = fixture.getSut()
        let child = sut.startChild(operation: fixture.transactionOperation)
                
        let grandChild = child.startChild(operation: fixture.transactionOperation)
        child.finish()
        
        assertTransactionNotCaptured(sut)
        
        let granGrandChild = grandChild.startChild(operation: fixture.transactionOperation)
        
        granGrandChild.finish()
        assertTransactionNotCaptured(sut)
        
        grandChild.finish()
        assertTransactionNotCaptured(sut)
        
        sut.finish()
        assertOneTransactionCaptured(sut)
        
        let serialization = getSerializedTransaction()
        let spans = serialization["spans"]! as! [[String: Any]]
        
        let tracerTimestamp: NSDate = sut.timestamp! as NSDate
        
        XCTAssertEqual(spans.count, 3)
        XCTAssertEqual(tracerTimestamp.sentry_toIso8601String(), serialization["timestamp"]! as! String)
        
        for span in spans {
            XCTAssertEqual(tracerTimestamp.sentry_toIso8601String(), span["timestamp"] as! String)
        }
    }
    
    func testFinish_WithChildren_DontWaitsForAllChildren() {
        let sut = fixture.getSut(waitForChildren: false)
        let child = sut.startChild(operation: fixture.transactionOperation)
        
        let grandChild = child.startChild(operation: fixture.transactionOperation)
        let granGrandChild = grandChild.startChild(operation: fixture.transactionOperation)
        
        granGrandChild.finish()
        assertTransactionNotCaptured(sut)
        
        grandChild.finish()
        assertTransactionNotCaptured(sut)
        
        child.finish()
        assertTransactionNotCaptured(sut)
        
        sut.finish()
        assertOneTransactionCaptured(sut)
        
        let serialization = getSerializedTransaction()
        let spans = serialization["spans"]! as! [[String: Any]]
        
        let tracerTimestamp: NSDate = sut.timestamp! as NSDate
        
        XCTAssertEqual(spans.count, 3)
        XCTAssertEqual(tracerTimestamp.sentry_toIso8601String(), serialization["timestamp"]! as! String)
        
        for span in spans {
            XCTAssertEqual(tracerTimestamp.sentry_toIso8601String(), span["timestamp"] as! String)
        }
    }
    
    func testFinish_WithoutHub_DoesntCaptureTransaction() {
        let sut = SentryTracer(transactionContext: fixture.transactionContext, hub: nil, waitForChildren: false)
        
        sut.finish()
        
        XCTAssertEqual(0, fixture.hub.capturedEventsWithScopes.count)
    }
    
    func testStartChild_FromChild_CheckParentId() {
        let sut = fixture.getSut()
        let child = sut.startChild(operation: fixture.transactionOperation)
        let grandChild = child.startChild(operation: fixture.transactionOperation)
        
        XCTAssertEqual(child.context.parentSpanId, sut.context.spanId )
        XCTAssertEqual(child.context.spanId, grandChild.context.parentSpanId )
    }
    
    func testStartChild_FromChild_CheckSpanList() {
        let sut = fixture.getSut()
        let child = sut.startChild(operation: fixture.transactionOperation)
        let grandChild = child.startChild(operation: fixture.transactionOperation)
        
        let children = Dynamic(sut).children as [Span]?
        
        XCTAssertEqual(children!.count, 2)
        XCTAssertTrue(children!.contains(where: { $0 === child }))
        XCTAssertTrue(children!.contains(where: { $0 === grandChild }))
    }
    
    // Although we only run this test above the below-specified versions, we expect the
    // implementation to be thread safe
    @available(tvOS 10.0, *)
    @available(OSX 10.12, *)
    @available(iOS 10.0, *)
    func testFinishAsync() {
        let sut = fixture.getSut()
        let child = sut.startChild(operation: fixture.transactionOperation)
        sut.finish()
        
        let queue = DispatchQueue(label: "SentryTracerTests", attributes: [.concurrent, .initiallyInactive])
        let group = DispatchGroup()
        
        for _ in 0 ..< 5_000 {
            group.enter()
            queue.async {
                let grandChild = child.startChild(operation: self.fixture.transactionOperation)
                for _ in 0 ..< 9 {
                    let grandGrandChild = grandChild.startChild(operation: self.fixture.transactionOperation)
                    grandGrandChild.finish()
                }
                
                grandChild.finish()
                group.leave()
                self.assertTransactionNotCaptured(sut)
            }
        }
        
        queue.activate()
        group.wait()
        
        child.finish()
        
        assertOneTransactionCaptured(sut)
        
        let spans = getSerializedTransaction()["spans"]! as! [[String: Any]]
        XCTAssertEqual(spans.count, 50_001)
    }
    
    private func getSerializedTransaction() -> [String: Any] {
        guard let transaction = fixture.hub.capturedEventsWithScopes.first?.event else {
            fatalError("Event must not be nil.")
        }
        return transaction.serialize()
    }
    
    private func assertTransactionNotCaptured(_ tracer: SentryTracer) {
        XCTAssertFalse(tracer.isFinished)
        XCTAssertEqual(0, fixture.hub.capturedEventsWithScopes.count)
    }
    
    private func assertOneTransactionCaptured(_ tracer: SentryTracer) {
        XCTAssertTrue(tracer.isFinished)
        XCTAssertEqual(1, fixture.hub.capturedEventsWithScopes.count)
    }
}
