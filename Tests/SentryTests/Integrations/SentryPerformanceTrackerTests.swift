import XCTest

class SentryPerformanceTrackerTests: XCTestCase {
    
    private static let dsnAsString = TestConstants.dsnAsString(username: "SentryPerformanceTrackerTests")
    
    private class Fixture {

        let someTransaction = "Some Transaction"
        let someOperation = "Some Operation"
        let client: TestClient
        let hub: TestHub
        let scope: Scope

        init() {
            scope = Scope()
            client = TestClient(options: Options())!
            hub = TestHub(client: client, andScope: scope)
        }
        
        func getSut() -> SentryPerformanceTracker {
            return  SentryPerformanceTracker()
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
    
    func testSingleton() {
        XCTAssertEqual(SentryPerformanceTracker.shared(), SentryPerformanceTracker.shared())
    }
   
    func testStartSpan_CheckScopeSpan() {
        let sut = fixture.getSut()
        let spanId = startSpan(tracker: sut)
        
        let transaction = sut.getSpan(spanId) as! SentryTracer
        
        let scopeSpan = fixture.scope.span
        
        XCTAssert(scopeSpan === transaction)
        XCTAssertTrue(transaction.waitForChildren)
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
  
    func testStartSpan_WithActiveSpan() {
        let sut = fixture.getSut()
        let spanId = startSpan(tracker: sut)
        
        sut.pushActiveSpan(spanId)
        
        let childSpanId = startSpan(tracker: sut)
        
        let transaction = sut.getSpan(spanId)
        let childSpan = sut.getSpan(childSpanId)
 
        let children = Dynamic(transaction).children as [Span]?
        
        XCTAssertEqual(1, children?.count)
        XCTAssert(children!.first === childSpan)
        XCTAssertEqual(spanId, childSpan?.context.parentSpanId)
    }
    
    func testActiveStack() {
        let sut = fixture.getSut()
        let spanId = startSpan(tracker: sut)
                
        XCTAssertNil(sut.activeSpan())
        
        sut.pushActiveSpan(spanId)
        XCTAssertEqual(sut.activeSpan(), spanId)
        
        let childSpanId = startSpan(tracker: sut)
        sut.pushActiveSpan(childSpanId)
        XCTAssertEqual(sut.activeSpan(), childSpanId)
        
        let grandChildSpanId = startSpan(tracker: sut)
        sut.pushActiveSpan(grandChildSpanId)
        XCTAssertEqual(sut.activeSpan(), grandChildSpanId)
        
        sut.popActiveSpan()
        XCTAssertEqual(sut.activeSpan(), childSpanId)
        
        sut.popActiveSpan()
        XCTAssertEqual(sut.activeSpan(), spanId)
        
        sut.popActiveSpan()
        XCTAssertNil(sut.activeSpan())
    }
    
    func testStartSpan_FromChild_CheckParent() {
        let sut = fixture.getSut()
        let spanId = startSpan(tracker: sut)
                
        sut.pushActiveSpan(spanId)
                
        let childSpanId = startSpan(tracker: sut)
        sut.pushActiveSpan(childSpanId)
                
        let grandChildSpanId = startSpan(tracker: sut)
                
        let root = sut.getSpan(spanId)
        let child = sut.getSpan(childSpanId)
        let grandchild = sut.getSpan(grandChildSpanId)
        
        XCTAssertEqual(root!.context.spanId, child!.context.parentSpanId)
        XCTAssertEqual(child!.context.spanId, grandchild!.context.parentSpanId)
    }
    
    func testMeasureSpanWithBlock() {
        let sut = fixture.getSut()
        var span: Span?
        
        let expect = expectation(description: "Callback Expectation")
        
        sut.measureSpan(withDescription: fixture.someTransaction, operation: fixture.someOperation) {
            let spanId = sut.activeSpan()!
            
            span = sut.getSpan(spanId)
            
            XCTAssertFalse(span!.isFinished)
            
            expect.fulfill()
        }
        
        XCTAssertNil(sut.activeSpan())
        XCTAssertTrue(span!.isFinished)
        wait(for: [expect], timeout: 0)
    }
    
    func testMeasureSpanWithBlock_SpanNotIsAlive_BlockIsCalled() {
        let sut = fixture.getSut()
        
        let expect = expectation(description: "Callback Expectation")
        
        sut.measureSpan(withDescription: fixture.someTransaction, operation: fixture.someOperation, parentSpanId: SpanId()) {
            expect.fulfill()
        }
        
        XCTAssertNil(sut.activeSpan())
        wait(for: [expect], timeout: 0)
    }
    
    func testNotSampled() {
        fixture.client.options.tracesSampleRate = 0
        let sut = fixture.getSut()
        let spanId = sut.startSpan(withName: fixture.someTransaction, operation: fixture.someOperation)
        let span = sut.getSpan(spanId)
        
        XCTAssertEqual(span!.context.sampled, .no)
    }
    
    func testSampled() {
        fixture.client.options.tracesSampleRate = 1
        let sut = fixture.getSut()
        let spanId = sut.startSpan(withName: fixture.someTransaction, operation: fixture.someOperation)
        let span = sut.getSpan(spanId)
        
        XCTAssertEqual(span!.context.sampled, .yes)
    }
    
    func testFinishSpan() {
        let sut = fixture.getSut()
        let spanId = startSpan(tracker: sut)
        
        sut.pushActiveSpan(spanId)
        let childId = startSpan(tracker: sut)
        
        let span = sut.getSpan(spanId)
        let child = sut.getSpan(childId)
        
        XCTAssertFalse(span!.isFinished)
        XCTAssertFalse(child!.isFinished)
        
        sut.finishSpan(childId)
        
        XCTAssertFalse(span!.isFinished)
        XCTAssertTrue(child!.isFinished)
        
        sut.finishSpan(spanId)
        
        let status = Dynamic(span).finishStatus as SentrySpanStatus?
        
        XCTAssertEqual(status!, .undefined)
        XCTAssertTrue(span!.isFinished)
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
        sut.pushActiveSpan(spanId)
        XCTAssertTrue(sut.isSpanAlive(spanId))

        let childId = startSpan(tracker: sut)
        XCTAssertTrue(sut.isSpanAlive(spanId))
        XCTAssertTrue(sut.isSpanAlive(childId))
        
        sut.finishSpan(childId)
        XCTAssertTrue(sut.isSpanAlive(spanId))
        XCTAssertFalse(sut.isSpanAlive(childId))
        
        sut.finishSpan(spanId)
        XCTAssertFalse(sut.isSpanAlive(spanId))
    }
    
    @available(tvOS 10.0, *)
    @available(OSX 10.12, *)
    @available(iOS 10.0, *)
    func testStartSpanAsync() {
        let sut = fixture.getSut()
        let spanId = startSpan(tracker: sut)
        sut.pushActiveSpan(spanId)
        
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
                
        let spans = getSpans(tracker: sut)
        XCTAssertEqual(spans.count, 5_001)
    }
    
    @available(tvOS 10.0, *)
    @available(OSX 10.12, *)
    @available(iOS 10.0, *)
    func testStackAsync() {
        let sut = fixture.getSut()
        let spanId = startSpan(tracker: sut)
        sut.pushActiveSpan(spanId)
        
        let queue = DispatchQueue(label: "SentryPerformanceTrackerTests", attributes: [.concurrent, .initiallyInactive])
        let group = DispatchGroup()
        
        for _ in 0 ..< 50_000 {
            group.enter()
            queue.async {
                let childId = self.startSpan(tracker: sut)
                sut.pushActiveSpan(childId)
                sut.popActiveSpan()
                group.leave()
            }
        }
        
        queue.activate()
        group.wait()
        
        sut.popActiveSpan()
        
        let stack = getStack(tracker: sut)
        XCTAssertEqual(0, stack.count)
        XCTAssertNil(sut.activeSpan())
    }
    
    private func getSpans(tracker: SentryPerformanceTracker) -> [SpanId: Span] {
        let result = Dynamic(tracker).spans as [SpanId: Span]?
        return result!
    }
    
    private func getStack(tracker: SentryPerformanceTracker) -> [Span] {
        let result = Dynamic(tracker).activeStack as [Span]?
        return result!
    }
    
    private func startSpan(tracker: SentryPerformanceTracker) -> SpanId {
        return tracker.startSpan(withName: fixture.someTransaction, operation: fixture.someOperation)
    }
    
}
