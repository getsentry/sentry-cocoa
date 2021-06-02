import XCTest

class SentryPerformanceTrackerTests: XCTestCase {
    
    private static let dsnAsString = TestConstants.dsnAsString(username: "SentryPerformanceTrackerTests")
    
    private class Fixture {

        let someTransaction = "Some Transaction"
        let someOperation = "Some Operation"
        
        func getSut(initSDK: Bool = false) -> SentryPerformanceTracker {
            if initSDK {
                SentrySDK.start { options in
                    options.dsn = SentryPerformanceTrackerTests.dsnAsString
                    options.debug = true
                    options.diagnosticLevel = SentryLevel.debug
                }
            }
            return  SentryPerformanceTracker()
        }

        func getSpans(tracker: SentryPerformanceTracker) -> [SpanId: Span] {
            let result = Dynamic(tracker).spans as [SpanId: Span]?
            return result!
        }
        
        func getStack(tracker: SentryPerformanceTracker) -> [Span] {
            let result = Dynamic(tracker).activeStack as [Span]?
            return result!
        }
    }
    
    private var fixture: Fixture!
    
    override func setUp() {
        
        fixture = Fixture()
    }
    
    override func tearDown() {
        SentrySDK.close()
    }
    
    func testSingleton() {
        XCTAssertEqual(SentryPerformanceTracker.shared(), SentryPerformanceTracker.shared())
    }
    
    func testStartSpan_CheckScopeSpan() {
        let tracker = fixture.getSut(initSDK: true)
        let spanid = tracker.startSpan(withName: fixture.someTransaction, operation: fixture.someOperation)
        let spans: [SpanId: Span] = fixture.getSpans(tracker: tracker)
        
        let transaction = spans[spanid] as! SentryTracer
        
        let scopeSpan = SentrySDK.currentHub().scope.span
        
        XCTAssert(scopeSpan === transaction)
        XCTAssertTrue(transaction.waitForChildren)
    }
    
    func testStartSpan_ScopeAlredyWithSpan() {
        let tracker = fixture.getSut(initSDK: true)

        let firstTransaction = SentrySDK.startTransaction(name: fixture.someTransaction, operation: fixture.someOperation, bindToScope: true)
        let spanid = tracker.startSpan(withName: fixture.someTransaction, operation: fixture.someOperation)
        let spans: [SpanId: Span] = fixture.getSpans(tracker: tracker)
        
        let transaction = spans[spanid]
        let scopeSpan = SentrySDK.currentHub().scope.span
        
        XCTAssert(scopeSpan !== transaction)
        XCTAssert(scopeSpan === firstTransaction)
    }
  
    func testStartSpan_WithActiveSpan() {
        let tracker = fixture.getSut()
        let spanid = tracker.startSpan(withName: fixture.someTransaction, operation: fixture.someOperation)
        
        tracker.pushActiveSpan(spanid)
        
        let childSpanId = tracker.startSpan(withName: fixture.someTransaction, operation: fixture.someOperation)
        let spans: [SpanId: Span] = fixture.getSpans(tracker: tracker)
        
        let transaction = spans[spanid]
        let childSpan = spans[childSpanId]
 
        let children = Dynamic(transaction).children as [Span]?
        
        XCTAssert(children!.first === childSpan)
        XCTAssertEqual(spanid, childSpan?.context.parentSpanId)
    }
    
    func testActiveStack() {
        let tracker = fixture.getSut()
        let spanid = tracker.startSpan(withName: fixture.someTransaction, operation: fixture.someOperation)
                
        XCTAssertNil(tracker.activeSpan())
        
        tracker.pushActiveSpan(spanid)
        XCTAssertEqual(tracker.activeSpan(), spanid)
        
        let childSpanId = tracker.startSpan(withName: fixture.someTransaction, operation: fixture.someOperation)
        tracker.pushActiveSpan(childSpanId)
        XCTAssertEqual(tracker.activeSpan(), childSpanId)
        
        let grandChildSpanId = tracker.startSpan(withName: fixture.someTransaction, operation: fixture.someOperation)
        tracker.pushActiveSpan(grandChildSpanId)
        XCTAssertEqual(tracker.activeSpan(), grandChildSpanId)
        
        tracker.popActiveSpan()
        XCTAssertEqual(tracker.activeSpan(), childSpanId)
        
        tracker.popActiveSpan()
        XCTAssertEqual(tracker.activeSpan(), spanid)
        
        tracker.popActiveSpan()
        XCTAssertNil(tracker.activeSpan())
    }
    
    func testStartSpan_FromChild_CheckParent() {
        let tracker = fixture.getSut()
        let spanid = tracker.startSpan(withName: fixture.someTransaction, operation: fixture.someOperation)
                
        tracker.pushActiveSpan(spanid)
                
        let childSpanId = tracker.startSpan(withName: fixture.someTransaction, operation: fixture.someOperation)
        tracker.pushActiveSpan(childSpanId)
                
        let grandChildSpanId = tracker.startSpan(withName: fixture.someTransaction, operation: fixture.someOperation)
        
        let spans = fixture.getSpans(tracker: tracker)
        
        let root = spans[spanid]
        let child = spans[childSpanId]
        let grandchild = spans[grandChildSpanId]
        
        XCTAssertEqual(root!.context.spanId, child!.context.parentSpanId)
        XCTAssertEqual(child!.context.spanId, grandchild!.context.parentSpanId)
    }
    
    func testMeasureSpanWithBlock() {
        let tracker = fixture.getSut()
        var span: Span?
        
        tracker.measureSpan(withDescription: fixture.someTransaction, operation: fixture.someOperation) {
            let spanId = tracker.activeSpan()!
            
            let spans = self.fixture.getSpans(tracker: tracker)
            span = spans[spanId]
            
            XCTAssertFalse(span!.isFinished)
        }
        
        XCTAssertNil(tracker.activeSpan())
        XCTAssertTrue(span!.isFinished)
    }
    
    func testFinishSpan() {
        let tracker = fixture.getSut()
        let spanId = tracker.startSpan(withName: fixture.someTransaction, operation: fixture.someOperation)
        
        tracker.pushActiveSpan(spanId)
        let childId = tracker.startSpan(withName: fixture.someTransaction, operation: fixture.someOperation)
        
        let spans = self.fixture.getSpans(tracker: tracker)
        let span = spans[spanId]
        let child = spans[childId]
        
        XCTAssertFalse(span!.isFinished)
        XCTAssertFalse(child!.isFinished)
        
        tracker.finishSpan(childId)
        
        XCTAssertFalse(span!.isFinished)
        XCTAssertTrue(child!.isFinished)
        
        tracker.finishSpan(spanId)
        
        let status = Dynamic(span).finishStatus as SentrySpanStatus?
        
        XCTAssertEqual(status!, .undefined)
        XCTAssertTrue(span!.isFinished)
    }
    
    func testFinishSpanWithStatus() {
        let tracker = fixture.getSut()
        let spanId = tracker.startSpan(withName: fixture.someTransaction, operation: fixture.someOperation)
                
        let spans = self.fixture.getSpans(tracker: tracker)
        let span = spans[spanId]
        
        tracker.finishSpan(spanId, with: .ok)
        
        let status = Dynamic(span).finishStatus as SentrySpanStatus?
        
        XCTAssertEqual(status!, .ok)
        XCTAssertTrue(span!.isFinished)
    }
    
    func testIsSpanAlive() {
        let tracker = fixture.getSut()
        let spanId = tracker.startSpan(withName: fixture.someTransaction, operation: fixture.someOperation)
        tracker.pushActiveSpan(spanId)
        XCTAssertTrue(tracker.isSpanAlive(spanId))

        let childId = tracker.startSpan(withName: fixture.someTransaction, operation: fixture.someOperation)
        XCTAssertTrue(tracker.isSpanAlive(spanId))
        XCTAssertTrue(tracker.isSpanAlive(childId))
        
        tracker.finishSpan(childId)
        XCTAssertTrue(tracker.isSpanAlive(spanId))
        XCTAssertFalse(tracker.isSpanAlive(childId))
        
        tracker.finishSpan(spanId)
        XCTAssertFalse(tracker.isSpanAlive(spanId))
    }
    
}
