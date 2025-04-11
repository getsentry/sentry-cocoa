@testable import Sentry
import XCTest

class SentryPropagationContextTests: XCTestCase {
    
    func testInitWithTraceIdSpanId() {
        let traceId = SentryId()
        let spanId = SpanId()
        
        let context = SentryPropagationContext(traceId: traceId, spanId: spanId)
        
        XCTAssertEqual(traceId, context.traceId)
        XCTAssertEqual(spanId, context.spanId)
    }
    
    func testTraceContextForEvent() {
        let traceId = SentryId()
        let spanId = SpanId()
        
        let context = SentryPropagationContext(traceId: traceId, spanId: spanId)
        
        let traceContext = context.traceContextForEvent()
        
        XCTAssertEqual(traceContext.count, 2)
        XCTAssertEqual(traceContext["trace_id"], traceId.sentryIdString)
        XCTAssertEqual(traceContext["span_id"], spanId.sentrySpanIdString)
    }
    
    func testTraceHeader() {
        let traceId = SentryId()
        let spanId = SpanId()
        
        let context = SentryPropagationContext(traceId: traceId, spanId: spanId)
        
        let traceHeader = context.traceHeader
        
        XCTAssertNotNil(traceHeader)
        XCTAssertEqual(traceHeader.traceId, traceId)
        XCTAssertEqual(traceHeader.spanId, spanId)
    }
} 
