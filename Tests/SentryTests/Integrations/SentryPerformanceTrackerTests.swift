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
        let firstTransaction = SentrySDK.startTransaction(name: fixture.someTransaction, operation: fixture.someOperation)
        
        let tracker = fixture.getSut(initSDK: true)
        let spanid = tracker.startSpan(withName: fixture.someTransaction, operation: fixture.someOperation)
        let spans: [SpanId: Span] = fixture.getSpans(tracker: tracker)
        
        let transaction = spans[spanid]
        let scopeSpan = SentrySDK.currentHub().scope.span
        
        XCTAssert(scopeSpan !== transaction)
        XCTAssert(scopeSpan === firstTransaction)
    }
  
    func testStartSpan_WithActiveSpan() {
        let tracker = fixture.getSut(initSDK: true)
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
        let tracker = fixture.getSut(initSDK: true)
        let spanid = tracker.startSpan(withName: fixture.someTransaction, operation: fixture.someOperation)
                
        XCTAssertNil(tracker.activeSpan())
        
        tracker.pushActiveSpan(spanid)
        XCTAssertEqual(tracker.activeSpan(), spanid)
        
        let childSpanId = tracker.startSpan(withName: fixture.someTransaction, operation: fixture.someOperation)
        tracker.pushActiveSpan(childSpanId)
        XCTAssertEqual(tracker.activeSpan(), childSpanId)
        
        let granChildSpanId = tracker.startSpan(withName: fixture.someTransaction, operation: fixture.someOperation)
        tracker.pushActiveSpan(granChildSpanId)
        XCTAssertEqual(tracker.activeSpan(), granChildSpanId)
        
        tracker.popActiveSpan()
        XCTAssertEqual(tracker.activeSpan(), childSpanId)
        
        tracker.popActiveSpan()
        XCTAssertEqual(tracker.activeSpan(), spanid)
        
        tracker.popActiveSpan()
        XCTAssertNil(tracker.activeSpan())
    }
}
