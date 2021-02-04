import XCTest

class SentrySpanContextTests: XCTestCase {
   
    func testInit() {
        let spanContext = SpanContext()
        XCTAssertFalse(spanContext.sampled)
        XCTAssertNil(spanContext.parentSpanId)
        XCTAssertNil(spanContext.operation)
        XCTAssertNil(spanContext.spanDescription)
        XCTAssertEqual(spanContext.tags.count, 0)
        XCTAssertEqual(spanContext.traceId.sentryIdString.count, 32)
        XCTAssertEqual(spanContext.spanId.sentrySpanIdString.count, 16)
    }
    
    func testInitWithSampled() {
        let spanContext = SpanContext(sampled: true)
        XCTAssertTrue(spanContext.sampled)
        XCTAssertNil(spanContext.operation)
        XCTAssertNil(spanContext.parentSpanId)
        XCTAssertNil(spanContext.spanDescription)
        XCTAssertEqual(spanContext.tags.count, 0)
        XCTAssertEqual(spanContext.traceId.sentryIdString.count, 32)
        XCTAssertEqual(spanContext.spanId.sentrySpanIdString.count, 16)
    }
    
    func testInitWithTraceIdSpanIdParentIdSampled() {
        let id = SentryId()
        let spanId = SpanId()
        let parentId = SpanId()
        
        let spanContext = SpanContext(trace: id, spanId: spanId, parentId: parentId, andSampled: true)
        
        XCTAssertEqual(id, spanContext.traceId)
        XCTAssertEqual(spanId, spanContext.spanId)
        XCTAssertEqual(parentId, spanContext.parentSpanId)
        XCTAssertTrue(spanContext.sampled)
        XCTAssertNil(spanContext.spanDescription)
        XCTAssertEqual(spanContext.tags.count, 0)
    }
    
    func testSerialization() {
        let id = SentryId()
        let spanId = SpanId()
        let parentId = SpanId()
        let operation = "Some Operation"
        
        let spanContext = SpanContext(trace: id, spanId: spanId, parentId: parentId, andSampled: true)
        spanContext.operation = operation
        spanContext.status = .ok
        
        let data = spanContext.serialize()
        
        XCTAssertEqual(data["span_id"] as? String, spanId.sentrySpanIdString)
        XCTAssertEqual(data["trace_id"] as? String, id.sentryIdString)
        XCTAssertEqual(data["type"] as? String, SpanContext.type)
        XCTAssertEqual(data["op"] as? String, operation)
        XCTAssertEqual(data["sampled"] as? String, "true")
        XCTAssertEqual(data["parent_span_id"] as? String, parentId.sentrySpanIdString)
        XCTAssertEqual(data["status"] as? String, "ok")
    }
    
    func testSpanContextTraceTypeValue() {
        XCTAssertEqual(SpanContext.type, "trace")
    }
    
    func testSetTags() {
        let tagKey =  "tag_key"
        let tagValue = "tag_value"
        
        let spanContext = SpanContext()
        spanContext.setTag(tagKey, withValue: tagValue)
        XCTAssertEqual(spanContext.tags.count, 1)
        XCTAssertEqual(spanContext.tags[tagKey], tagValue)
    }
    
    func testUnsetTags() {
        let tagKey =  "tag_key"
        let tagValue = "tag_value"
        
        let spanContext = SpanContext()
        spanContext.setTag(tagKey, withValue: tagValue)
        XCTAssertEqual(spanContext.tags.count, 1)
        spanContext.unsetTag(tagKey)
        XCTAssertEqual(spanContext.tags.count, 0)
        XCTAssertNil(spanContext.tags[tagKey])
    }
    
}
