import XCTest

class SentrySpanContextTests: XCTestCase {
    let someOperation = "Some Operation"
    
    func testInit() {
        let spanContext = SpanContext(operation: someOperation)
        XCTAssertEqual(spanContext.sampled, SentrySampleDecision.undecided)
        XCTAssertNil(spanContext.parentSpanId)
        XCTAssertEqual(spanContext.operation, someOperation)
        XCTAssertNil(spanContext.spanDescription)
        XCTAssertEqual(spanContext.traceId.sentryIdString.count, 32)
        XCTAssertEqual(spanContext.spanId.sentrySpanIdString.count, 16)
    }
    
    func testInitWithSampled() {
        let spanContext = SpanContext(operation: someOperation, sampled: .yes)
        XCTAssertEqual(spanContext.sampled, .yes)
        XCTAssertEqual(spanContext.operation, someOperation)
        XCTAssertNil(spanContext.parentSpanId)
        XCTAssertNil(spanContext.spanDescription)
        XCTAssertEqual(spanContext.traceId.sentryIdString.count, 32)
        XCTAssertEqual(spanContext.spanId.sentrySpanIdString.count, 16)
    }
    
    func testInitWithTraceIdSpanIdParentIdSampled() {
        let id = SentryId()
        let spanId = SpanId()
        let parentId = SpanId()
        
        let spanContext = SpanContext(trace: id, spanId: spanId, parentId: parentId, operation: someOperation, sampled: .yes)
        
        XCTAssertEqual(id, spanContext.traceId)
        XCTAssertEqual(spanId, spanContext.spanId)
        XCTAssertEqual(parentId, spanContext.parentSpanId)
        XCTAssertEqual(spanContext.sampled, .yes)
        XCTAssertNil(spanContext.spanDescription)
        XCTAssertEqual(spanContext.operation, someOperation)
    }
    
    func testSerialization() {
        let id = SentryId()
        let spanId = SpanId()
        let parentId = SpanId()
        
        let spanContext = SpanContext(trace: id, spanId: spanId, parentId: parentId, operation: someOperation, spanDescription: "description", sampled: .yes)
        
        let data = spanContext.serialize()
        
        XCTAssertEqual(data["span_id"] as? String, spanId.sentrySpanIdString)
        XCTAssertEqual(data["trace_id"] as? String, id.sentryIdString)
        XCTAssertEqual(data["type"] as? String, SpanContext.type)
        XCTAssertEqual(data["op"] as? String, someOperation)
        XCTAssertEqual(data["description"] as? String, spanContext.spanDescription)
        XCTAssertEqual(data["sampled"] as? String, "true")
        XCTAssertEqual(data["parent_span_id"] as? String, parentId.sentrySpanIdString)
    }
    
    func testSerialization_NotSettingProperties_PropertiesNotSerialized() {
        let spanContext = SpanContext(operation: someOperation)
        
        let data = spanContext.serialize()
        
        XCTAssertNil(data["description"])
        XCTAssertNil(data["sampled"])
        XCTAssertNil(data["parent_span_id"])
        XCTAssertNil(data["tags"])
    }

    func testSamplerDecisionNames() {
        XCTAssertEqual(kSentrySampleDecisionNameUndecided, nameForSentrySampleDecision(.undecided))
        XCTAssertEqual(kSentrySampleDecisionNameNo, nameForSentrySampleDecision(.no))
        XCTAssertEqual(kSentrySampleDecisionNameYes, nameForSentrySampleDecision(.yes))
    }
    
    func testSampledNoSerialization() {
        let id = SentryId()
        let spanId = SpanId()
        let parentId = SpanId()
        
        let spanContext = SpanContext(trace: id, spanId: spanId, parentId: parentId, operation: someOperation, sampled: .no)
        
        let data = spanContext.serialize()
        
        XCTAssertEqual(data["sampled"] as? String, "false")
    }
    
    func testSampleUndecidedSerialization() {
        let id = SentryId()
        let spanId = SpanId()
        let parentId = SpanId()
        
        let spanContext = SpanContext(trace: id, spanId: spanId, parentId: parentId, operation: someOperation, sampled: .undecided)
        
        let data = spanContext.serialize()
        
        XCTAssertNil(data["sampled"] )
    }
    
    func testSpanContextTraceTypeValue() {
        XCTAssertEqual(SpanContext.type, "trace")
    }
}
