@testable import Sentry
import XCTest

class SentryPropagationContextTests: XCTestCase {
    
    func testInitWithTraceIdSpanId() {
        // -- Arrange --
        let traceId = SentryId()
        let spanId = SpanId()

        // -- Act --
        let context = SentryPropagationContext(traceId: traceId, spanId: spanId)
        
        // -- Assert --
        XCTAssertEqual(traceId, context.traceId)
        XCTAssertEqual(spanId, context.spanId)
    }
    
    func testTraceContextForEvent() {
        // -- Arrange --
        let traceId = SentryId()
        let spanId = SpanId()
        
        let context = SentryPropagationContext(traceId: traceId, spanId: spanId)
        
        // -- Act --
        let traceContext = context.traceContextForEvent()
        
        // -- Assert --
        XCTAssertEqual(traceContext.count, 2)
        XCTAssertEqual(traceContext["trace_id"], traceId.sentryIdString)
        XCTAssertEqual(traceContext["span_id"], spanId.sentrySpanIdString)
    }
    
    func testTraceHeader() {
        // -- Arrange
        let traceId = SentryId()
        let spanId = SpanId()
        
        let context = SentryPropagationContext(traceId: traceId, spanId: spanId)
        
        // -- Act --
        let traceHeader = context.traceHeader
        
        // -- Assert --
        XCTAssertNotNil(traceHeader)
        XCTAssertEqual(traceHeader.traceId, traceId)
        XCTAssertEqual(traceHeader.spanId, spanId)
    }
} 
