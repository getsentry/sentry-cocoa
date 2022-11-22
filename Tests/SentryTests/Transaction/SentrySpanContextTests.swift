import XCTest

class SentrySpanContextTests: XCTestCase {
    let someOperation = "Some Operation"
    
    func testInit() {
        let spanContext = SpanContext(operation: someOperation)
        XCTAssertEqual(spanContext.sampled, SentrySampleDecision.undecided)
        XCTAssertNil(spanContext.parentSpanId)
        XCTAssertEqual(spanContext.operation, someOperation)
        XCTAssertNil(spanContext.spanDescription)
        XCTAssertEqual(spanContext.tags.count, 0)
        XCTAssertEqual(spanContext.traceId.sentryIdString.count, 32)
        XCTAssertEqual(spanContext.spanId.sentrySpanIdString.count, 16)
    }
    
    func testInitWithSampled() {
        let spanContext = SpanContext(operation: someOperation, sampled: .yes)
        XCTAssertEqual(spanContext.sampled, .yes)
        XCTAssertEqual(spanContext.operation, someOperation)
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
        
        let spanContext = SpanContext(trace: id, spanId: spanId, parentId: parentId, operation: someOperation, sampled: .yes)
        
        XCTAssertEqual(id, spanContext.traceId)
        XCTAssertEqual(spanId, spanContext.spanId)
        XCTAssertEqual(parentId, spanContext.parentSpanId)
        XCTAssertEqual(spanContext.sampled, .yes)
        XCTAssertNil(spanContext.spanDescription)
        XCTAssertEqual(spanContext.tags.count, 0)
        XCTAssertEqual(spanContext.operation, someOperation)
    }
    
    func testSerialization() {
        let id = SentryId()
        let spanId = SpanId()
        let parentId = SpanId()
        
        let spanContext = SpanContext(trace: id, spanId: spanId, parentId: parentId, operation: someOperation, sampled: .yes)
        spanContext.status = .ok
        spanContext.spanDescription = "description"
        
        let data = spanContext.serialize()
        
        XCTAssertEqual(data["span_id"] as? String, spanId.sentrySpanIdString)
        XCTAssertEqual(data["trace_id"] as? String, id.sentryIdString)
        XCTAssertEqual(data["type"] as? String, SpanContext.type)
        XCTAssertEqual(data["op"] as? String, someOperation)
        XCTAssertEqual(data["description"] as? String, spanContext.spanDescription)
        XCTAssertEqual(data["sampled"] as? String, "true")
        XCTAssertEqual(data["parent_span_id"] as? String, parentId.sentrySpanIdString)
        XCTAssertEqual(data["status"] as? String, "ok")
    }
    
    func testSerialization_NotSettingProperties_PropertiesNotSerialized() {
        let spanContext = SpanContext(operation: someOperation)
        
        let data = spanContext.serialize()
        
        XCTAssertNil(data["description"])
        XCTAssertNil(data["sampled"])
        XCTAssertNil(data["parent_span_id"])
        XCTAssertNil(data["status"])
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
        spanContext.status = .ok
        
        let data = spanContext.serialize()
        
        XCTAssertEqual(data["sampled"] as? String, "false")
    }
    
    func testSampleUndecidedSerialization() {
        let id = SentryId()
        let spanId = SpanId()
        let parentId = SpanId()
        
        let spanContext = SpanContext(trace: id, spanId: spanId, parentId: parentId, operation: someOperation, sampled: .undecided)
        spanContext.status = .ok
        
        let data = spanContext.serialize()
        
        XCTAssertNil(data["sampled"] )
    }
    
    func testSpanContextTraceTypeValue() {
        XCTAssertEqual(SpanContext.type, "trace")
    }
    
    func testSetTags() {
        let tagKey = "tag_key"
        let tagValue = "tag_value"
        
        let spanContext = SpanContext(operation: someOperation)
        spanContext.setTag(value: tagValue, key: tagKey)
        XCTAssertEqual(spanContext.tags.count, 1)
        XCTAssertEqual(spanContext.tags[tagKey], tagValue)
    }
    
    func testUnsetTags() {
        let tagKey = "tag_key"
        let tagValue = "tag_value"
        
        let spanContext = SpanContext(operation: someOperation)
        spanContext.setTag(value: tagValue, key: tagKey)
        XCTAssertEqual(spanContext.tags.count, 1)
        spanContext.removeTag(key: tagKey)
        XCTAssertEqual(spanContext.tags.count, 0)
        XCTAssertNil(spanContext.tags[tagKey])
    }
    
    func testModifyingTagsFromMultipleThreads() {
        let queue = DispatchQueue(label: "SentrySpanTests", qos: .userInteractive, attributes: [.concurrent, .initiallyInactive])
        let group = DispatchGroup()
        
        let tagValue = "tag_value"
        
        let spanContext = SpanContext(operation: someOperation)
        
        // The number is kept small for the CI to not take to long.
        // If you really want to test this increase to 100_000 or so.
        let innerLoop = 1_000
        let outerLoop = 20
        
        for i in 0..<outerLoop {
            group.enter()
            queue.async {
                
                for j in 0..<innerLoop {
                    spanContext.setTag(value: tagValue, key: "\(i)-\(j)")
                }
                
                group.leave()
            }
        }
        
        queue.activate()
        group.wait()
        XCTAssertEqual(spanContext.tags.count, outerLoop * innerLoop)
    }
    
}
