import SentryTestUtils
import XCTest

class SentryPerformanceTrackerTests: XCTestCase {
    
    private static let dsnAsString = TestConstants.dsnAsString(username: "SentryPerformanceTrackerTests")
    
    private class Fixture {

        let someTransaction = "Some Transaction"
        let someOperation = "Some Operation"
        let client: TestClient!
        let hub: TestHub
        let scope: Scope

        init() {
            scope = Scope()
            client = TestClient(options: Options())
            hub = TestHub(client: client, andScope: scope)
        }
        
        func getSut() -> SentryPerformanceTracker {
            return SentryPerformanceTracker()
        }
    }
    
    private var fixture: Fixture!
    
    override func setUp() {
        super.setUp()
        
        fixture = Fixture()
        SentrySDK.setCurrentHub(fixture.hub)
    }
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }
   
    func testStartSpan_CheckScopeSpan() {
        let sut = fixture.getSut()
        let spanId = startSpan(tracker: sut)
        
        let transaction = sut.getSpan(spanId) as! SentryTracer
        
        let scopeSpan = fixture.scope.span
        
        XCTAssert(scopeSpan === transaction)
        XCTAssertTrue(Dynamic(transaction).configuration.waitForChildren.asBool ?? false)
        XCTAssertEqual(transaction.transactionContext.name, fixture.someTransaction)
        XCTAssertEqual(transaction.transactionContext.nameSource, .custom)
    }
    
    func testStartSpan_ScopeAlreadyWithSpan() {
        let sut = fixture.getSut()

        let firstTransaction = SentrySDK.startTransaction(name: fixture.someTransaction, operation: fixture.someOperation, bindToScope: true)
        let spanId = startSpan(tracker: sut)
                
        let transaction = sut.getSpan(spanId)
        let scopeSpan = SentrySDK.currentHub().scope.span
        
        XCTAssert(scopeSpan !== transaction)
        XCTAssert(scopeSpan === firstTransaction)
    }
    
    func testStartSpan_ScopeWithUIActionSpan_FinishesSpan() {
        let sut = fixture.getSut()
        let firstTransaction = SentrySDK.startTransaction(name: fixture.someTransaction, operation: "ui.action", bindToScope: true)
        let spanId = startSpan(tracker: sut)
                
        let transaction = sut.getSpan(spanId)
        let scopeSpan = SentrySDK.currentHub().scope.span
        
        XCTAssert(scopeSpan === transaction)
        XCTAssert(scopeSpan !== firstTransaction)
        XCTAssertTrue(firstTransaction.isFinished)
        XCTAssertEqual(.cancelled, firstTransaction.status)
    }
    
    func testStartSpan_WithActiveSpan() {
        let sut = fixture.getSut()
        let spanId = startSpan(tracker: sut)
        var blockCalled = false
        
        sut.activateSpan(spanId) {
            blockCalled = true
            
            let childSpanId = self.startSpan(tracker: sut)
            
            let transaction = sut.getSpan(spanId)
            let childSpan = sut.getSpan(childSpanId)
            
            let children = Dynamic(transaction).children as [Span]?
            
            XCTAssertEqual(1, children?.count)
            XCTAssert(children!.first === childSpan)
            XCTAssertEqual(spanId, childSpan?.parentSpanId)
        }
        XCTAssertTrue(blockCalled)
    }
    
    func testActiveStack() {
        let sut = fixture.getSut()
        let spanId = startSpan(tracker: sut)
        var blockCalled = false
        
        XCTAssertNil(sut.activeSpanId())
        
        sut.activateSpan(spanId) {
            XCTAssertEqual(sut.activeSpanId(), spanId)
           
            let childSpanId = self.startSpan(tracker: sut)
            sut.activateSpan(childSpanId) {
                XCTAssertEqual(sut.activeSpanId(), childSpanId)

                let grandChildSpanId = self.startSpan(tracker: sut)
                sut.activateSpan(grandChildSpanId) {
                    XCTAssertEqual(sut.activeSpanId(), grandChildSpanId)
                    blockCalled = true
                }
                XCTAssertEqual(sut.activeSpanId(), childSpanId)
            }
            XCTAssertEqual(sut.activeSpanId(), spanId)
        }
        XCTAssertNil(sut.activeSpanId())
        XCTAssertTrue(blockCalled)
    }
    
    func testStartSpan_FromChild_CheckParent() {
        let sut = fixture.getSut()
        
        var root: Span!
        var child: Span!
        var grandchild: Span!
        
        let spanId = startSpan(tracker: sut)
        root = sut.getSpan(spanId)
        sut.activateSpan(spanId) {
            let childSpanId = self.startSpan(tracker: sut)
            child = sut.getSpan(childSpanId)
            sut.activateSpan(childSpanId) {
                let grandChildSpanId = self.startSpan(tracker: sut)
                grandchild = sut.getSpan(grandChildSpanId)
            }
        }
        XCTAssertEqual(root!.spanId, child.parentSpanId)
        XCTAssertEqual(child!.spanId, grandchild.parentSpanId)
    }
    
    func testMeasureSpanWithBlock() {
        let sut = fixture.getSut()
        var span: Span?
        
        let expect = expectation(description: "Callback Expectation")
        
        sut.measureSpan(withDescription: fixture.someTransaction, operation: fixture.someOperation) {
            let spanId = sut.activeSpanId()!
            
            span = sut.getSpan(spanId)
            
            XCTAssertFalse(span!.isFinished)
            
            expect.fulfill()
        }
        
        XCTAssertNil(sut.activeSpanId())
        XCTAssertTrue(span!.isFinished)
        wait(for: [expect], timeout: 0)
    }
    
    func testMeasureSpanWithBlock_SpanNotIsAlive_BlockIsCalled() {
        let sut = fixture.getSut()
        
        let expect = expectation(description: "Callback Expectation")
        
        sut.measureSpan(withDescription: fixture.someTransaction, operation: fixture.someOperation, parentSpanId: SpanId()) {
            expect.fulfill()
        }
        
        XCTAssertNil(sut.activeSpanId())
        wait(for: [expect], timeout: 0)
    }
    
    func testNotSampled() {
        fixture.client.options.tracesSampleRate = 0
        let sut = fixture.getSut()
        let spanId = sut.startSpan(withName: fixture.someTransaction, operation: fixture.someOperation)
        let span = sut.getSpan(spanId)
        
        XCTAssertEqual(span!.sampled, .no)
    }
    
    func testSampled() {
        fixture.client.options.tracesSampleRate = 1
        let sut = fixture.getSut()
        let spanId = sut.startSpan(withName: fixture.someTransaction, operation: fixture.someOperation)
        let span = sut.getSpan(spanId)
        
        XCTAssertEqual(span!.sampled, .yes)
    }
    
    func testFinishSpan() {
        let sut = fixture.getSut()
        let spanId = startSpan(tracker: sut)
        let span = sut.getSpan(spanId)
        var blockCalled = false

        XCTAssertEqual(getSpans(tracker: sut).count, 1)

        sut.activateSpan(spanId) {
            blockCalled = true
            let childId = self.startSpan(tracker: sut)
            let child = sut.getSpan(childId)
            XCTAssertEqual(self.getSpans(tracker: sut).count, 2)
            XCTAssertFalse(span!.isFinished)
            XCTAssertFalse(child!.isFinished)
            
            sut.finishSpan(childId)
            
            XCTAssertFalse(span!.isFinished)
            XCTAssertTrue(child!.isFinished)
        }

        XCTAssertEqual(getSpans(tracker: sut).count, 1)
        sut.finishSpan(spanId)
        let status = Dynamic(span).finishStatus as SentrySpanStatus?
        
        XCTAssertEqual(status!, .ok)
        XCTAssertTrue(span!.isFinished)
        XCTAssertTrue(blockCalled)
        XCTAssertEqual(getSpans(tracker: sut).count, 0)
    }
    
    func testFinishSpanWithStatus() {
        let sut = fixture.getSut()
        let spanId = startSpan(tracker: sut)
        
        let span = sut.getSpan(spanId)
        
        sut.finishSpan(spanId, with: .ok)
        
        let status = Dynamic(span).finishStatus as SentrySpanStatus?
        
        XCTAssertEqual(status!, .ok)
        XCTAssertTrue(span!.isFinished)
    }
    
    func testIsSpanAlive() {
        let sut = fixture.getSut()
        let spanId = startSpan(tracker: sut)
        var blockCalled = false
        sut.activateSpan(spanId) {
            blockCalled = true
            XCTAssertTrue(sut.isSpanAlive(spanId))
            
            let childId = self.startSpan(tracker: sut)
            XCTAssertTrue(sut.isSpanAlive(spanId))
            XCTAssertTrue(sut.isSpanAlive(childId))
            
            sut.finishSpan(childId)
            XCTAssertTrue(sut.isSpanAlive(spanId))
            XCTAssertFalse(sut.isSpanAlive(childId))
        }
        sut.finishSpan(spanId)
        XCTAssertFalse(sut.isSpanAlive(spanId))
        XCTAssertTrue(blockCalled)
    }
    
    func testActiveStackReturnNilChildSpan() {
        let sut = fixture.getSut()
        let activeSpans = Dynamic(sut).activeSpanStack as NSMutableArray?
        activeSpans?.add(TestSentrySpan())
                
        let spanId = sut.startSpan(withName: fixture.someTransaction, operation: fixture.someOperation)
        
        XCTAssertEqual(spanId, SpanId.empty)
    }
        
    func testStartSpanAsync() {
        let sut = fixture.getSut()
        let spanId = startSpan(tracker: sut)
        sut.activateSpan(spanId) {
            
            let queue = DispatchQueue(label: "SentryPerformanceTrackerTests", attributes: [.concurrent, .initiallyInactive])
            let group = DispatchGroup()

            for _ in 0 ..< 5_000 {
                group.enter()
                queue.async {
                    _ = self.startSpan(tracker: sut)
                    group.leave()
                }
            }
            
            queue.activate()
            group.wait()
        }
        let spans = getSpans(tracker: sut)
        XCTAssertEqual(spans.count, 5_001)
        for span in spans {
            sut.finishSpan(span.key)
        }
    }
    
    func testStackAsync() {
        let sut = fixture.getSut()
        let spanId = startSpan(tracker: sut)
        sut.activateSpan(spanId) {
            
            let queue = DispatchQueue(label: "SentryPerformanceTrackerTests", attributes: [.concurrent, .initiallyInactive])
            let group = DispatchGroup()
            
            for _ in 0 ..< 50 {
                group.enter()
                queue.async {
                    let childId = self.startSpan(tracker: sut)
                    sut.activateSpan(childId) {
                    }
                    group.leave()
                }
            }
            
            queue.activate()
            group.wait()
        }
        
        let stack = getStack(tracker: sut)
        XCTAssertEqual(0, stack.count)
        XCTAssertNil(sut.activeSpanId())
    }
    
    private func getSpans(tracker: SentryPerformanceTracker) -> [SpanId: Span] {
        let result = Dynamic(tracker).spans as [SpanId: Span]?
        return result!
    }
    
    private func getStack(tracker: SentryPerformanceTracker) -> [Span] {
        let result = Dynamic(tracker).activeSpanStack as [Span]?
        return result!
    }
    
    private func startSpan(tracker: SentryPerformanceTracker) -> SpanId {
        return tracker.startSpan(withName: fixture.someTransaction, operation: fixture.someOperation)
    }
        
}
