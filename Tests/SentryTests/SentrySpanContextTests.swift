import XCTest

class SentrySpanContextTest: XCTestCase {
   
    func testInitWithSampled()
    {
        let spanContext = SentrySpanContext(sampled: true)
        XCTAssertTrue(spanContext.sampled)
    }
    
    func testInitWithTraceIdSpanIdParentIdSampled()
    {
        let id = SentryId()
        let spanId = SentrySpanId()
        let parentId = SentrySpanId()
        
        let spanContext = SentrySpanContext(trace: id, spanId: spanId, parentId: parentId, andSampled: true)
        
        XCTAssertEqual(id, spanContext.traceId)
        XCTAssertEqual(spanId, spanContext.spanId)
        XCTAssertEqual(parentId, spanContext.parentSpanId)
        XCTAssertTrue(spanContext.sampled)
    }
    
    func testSerialization()
    {
        let id = SentryId()
        let spanId = SentrySpanId()
        let parentId = SentrySpanId()
        let operation = "Some Operation"
        
        let spanContext = SentrySpanContext(trace: id, spanId: spanId, parentId: parentId, andSampled: true)
        spanContext.operation = operation
        spanContext.status = .ok
        
        let data = spanContext.serialize()
        
        XCTAssertEqual(data["span_id"] as? String, spanId.sentrySpanIdString)
        XCTAssertEqual(data["trace_id"] as? String, id.sentryIdString)
        XCTAssertEqual(data["type"] as? String, SentrySpanContext.type())
        XCTAssertEqual(data["op"] as? String, operation)
        XCTAssertEqual(data["sampled"] as? String, "true")
        XCTAssertEqual(data["parent_span_id"] as? String, parentId.sentrySpanIdString)
        XCTAssertEqual(data["status"] as? String, "ok")
    }
}
