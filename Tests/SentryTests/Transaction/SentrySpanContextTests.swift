@testable import Sentry
import XCTest

class SentrySpanContextTests: XCTestCase {
    let operation = "ui.load"
    let transactionName = "Screen Load"
    let origin = "auto.ui.swift_ui"
    let spanDescription = "span description"
    let traceID = SentryId()
    let spanID = SpanId()
    let parentSpanID = SpanId()
    let sampled = SentrySampleDecision.yes
    let sampleRate = NSNumber(value: 0.123456789)
    let sampleRand = NSNumber(value: 0.333)

    // MARK: - Legacy Tests

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
        XCTAssertEqual(data["type"] as? String, SENTRY_TRACE_TYPE)
        XCTAssertEqual(data["op"] as? String, someOperation)
        XCTAssertEqual(data["description"] as? String, spanContext.spanDescription)
        XCTAssertEqual(data["sampled"] as? NSNumber, true)
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
        XCTAssertNil(valueForSentrySampleDecision(.undecided))
        XCTAssertFalse(valueForSentrySampleDecision(.no).boolValue)
        XCTAssertTrue(valueForSentrySampleDecision(.yes).boolValue)
    }
    
    func testSampledNoSerialization() {
        let id = SentryId()
        let spanId = SpanId()
        let parentId = SpanId()
        
        let spanContext = SpanContext(trace: id, spanId: spanId, parentId: parentId, operation: someOperation, sampled: .no)
        
        let data = spanContext.serialize()
        
        XCTAssertFalse(try XCTUnwrap(data["sampled"] as? Bool))
    }
    
    func testSampleUndecidedSerialization() {
        let id = SentryId()
        let spanId = SpanId()
        let parentId = SpanId()
        
        let spanContext = SpanContext(trace: id, spanId: spanId, parentId: parentId, operation: someOperation, sampled: .undecided)
        
        let data = spanContext.serialize()
        
        XCTAssertNil(data["sampled"] )
    }

    // MARK: - SentrySpanContext - Public Initializers

    func testPublicInit_WithOperation() {
        // Act
        let context = SpanContext(operation: operation)

        // Assert
        assertContext(
            context: context,
            expectedParentSpanId: nil,
            expectedOperation: operation,
            expectedOrigin: SentryTraceOrigin.manual,
            expectedSpanDescription: nil,
            expectedSampled: .undecided,
            expectedSampleRate: nil,
            expectedSampleRand: nil
        )
    }

    func testPublicInit_WithOperationSampled() {
        // Act
        let context = SpanContext(operation: operation, sampled: sampled)

        // Assert
        assertContext(
            context: context,
            expectedParentSpanId: nil,
            expectedOperation: operation,
            expectedOrigin: SentryTraceOrigin.manual,
            expectedSpanDescription: nil,
            expectedSampled: sampled,
            expectedSampleRate: nil,
            expectedSampleRand: nil
        )
    }

    func testPublicInit_WithOperationSampledSampleRateSampleRand() {
        // Act
        let context = SpanContext(
            operation: operation,
            sampled: sampled,
            sampleRate: sampleRate,
            sampleRand: sampleRand
        )

        // Assert
        assertContext(
            context: context,
            expectedParentSpanId: nil,
            expectedOperation: operation,
            expectedOrigin: SentryTraceOrigin.manual,
            expectedSpanDescription: nil,
            expectedSampled: sampled,
            expectedSampleRate: sampleRate,
            expectedSampleRand: sampleRand
        )
    }

    func testPublicInit_WithTraceIdSpanIdParentIdOperationSampled() {
        // Act
        let context = SpanContext(
            trace: traceID,
            spanId: spanID,
            parentId: parentSpanID,
            operation: operation,
            sampled: sampled
        )

        // Assert
        assertContext(
            context: context,
            expectedParentSpanId: parentSpanID,
            expectedOperation: operation,
            expectedOrigin: SentryTraceOrigin.manual,
            expectedSpanDescription: nil,
            expectedSampled: sampled,
            expectedSampleRate: nil,
            expectedSampleRand: nil
        )
    }

    func testPublicInit_WithTraceIdSpanIdParentIdOperationSampledSampleRateSampleRand() {
        // Act
        let context = SpanContext(
            trace: traceID,
            spanId: spanID,
            parentId: parentSpanID,
            operation: operation,
            sampled: sampled,
            sampleRate: sampleRate,
            sampleRand: sampleRand
        )

        // Assert
        assertContext(
            context: context,
            expectedParentSpanId: nil,
            expectedOperation: operation,
            expectedOrigin: SentryTraceOrigin.manual,
            expectedSpanDescription: nil,
            expectedSampled: sampled,
            expectedSampleRate: sampleRate,
            expectedSampleRand: sampleRand
        )
    }

    func testPublicInit_WithTraceIdSpanIdParentIdOperationSpanDescriptionSampled() {
        // Act
        let context = SpanContext(
            trace: traceID,
            spanId: spanID,
            parentId: parentSpanID,
            operation: operation,
            spanDescription: spanDescription,
            sampled: sampled
        )

        // Assert
        assertContext(
            context: context,
            expectedParentSpanId: parentSpanID,
            expectedOperation: operation,
            expectedOrigin: SentryTraceOrigin.manual,
            expectedSpanDescription: nil,
            expectedSampled: sampled,
            expectedSampleRate: nil,
            expectedSampleRand: nil
        )
    }

    func testPublicInit_WithTraceIdSpanIdParentIdOperationSpanDescriptionSampledSampleRateSampleRand() {
        // Act
        let context = SpanContext(
            trace: traceID,
            spanId: spanID,
            parentId: parentSpanID,
            operation: operation,
            spanDescription: spanDescription,
            sampled: sampled,
            sampleRate: sampleRate,
            sampleRand: sampleRand
        )

        // Assert
        assertContext(
            context: context,
            expectedParentSpanId: parentSpanID,
            expectedOperation: operation,
            expectedOrigin: SentryTraceOrigin.manual,
            expectedSpanDescription: spanDescription,
            expectedSampled: sampled,
            expectedSampleRate: sampleRate,
            expectedSampleRand: sampleRand
        )
    }

    // MARK: - Serialization

    func testSerialization_minimalData_shouldNotIncludeNilValues() {
        // Arrange
        let spanContext = SpanContext(
            trace: traceID,
            spanId: spanID,
            parentId: parentSpanID,
            operation: operation,
            spanDescription: nil,
            sampled: .undecided,
            sampleRate: nil,
            sampleRand: nil
        )

        // Act
        let data = spanContext.serialize()

        // Assert
        XCTAssertEqual(data["type"] as? String, SENTRY_TRACE_TYPE)
        XCTAssertEqual(data["trace_id"] as? String, traceID.sentryIdString)
        XCTAssertEqual(data["span_id"] as? String, spanID.sentrySpanIdString)
        XCTAssertEqual(data["op"] as? String, operation)
        XCTAssertNil(data["sampled"])
        XCTAssertNil(data["sample_rate"])
        XCTAssertNil(data["sample_rand"])
        XCTAssertNil(data["description"])
        XCTAssertNil(data["parent_span_id"])
    }

    func testSerialization_notSettingProperties_shouldNotSerialize() {
        // Arrange
        let spanContext = SpanContext(operation: operation)

        // Act
        let data = spanContext.serialize()

        // Assert
        XCTAssertEqual(data["type"] as? String, SENTRY_TRACE_TYPE)
        XCTAssertEqual(data["trace_id"] as? String, spanContext.traceId.sentryIdString)
        XCTAssertEqual(data["span_id"] as? String, spanContext.traceId.sentryIdString)
        XCTAssertEqual(data["op"] as? String, operation)
        XCTAssertNil(data["origin"])
        XCTAssertNil(data["sampled"])
        XCTAssertNil(data["sample_rate"])
        XCTAssertNil(data["sample_rand"])
        XCTAssertNil(data["description"])
        XCTAssertNil(data["parent_span_id"])
    }

    func testSerialization_sampledDecisionYes_shouldSerializeToTrue() {
        // Arrange
        let spanContext = SpanContext(
            trace: traceID,
            spanId: spanID,
            parentId: parentSpanID,
            operation: operation,
            spanDescription: nil,
            sampled: .yes,
            sampleRate: nil,
            sampleRand: nil
        )

        // Act
        let data = spanContext.serialize()

        // Assert
        XCTAssertEqual(data["sampled"] as? Bool, true)
    }

    func testSerialization_sampledDecisionNo_shouldSerializeToFalse() {
        // Arrange
        let spanContext = SpanContext(
            trace: traceID,
            spanId: spanID,
            parentId: parentSpanID,
            operation: operation,
            sampled: .no,
            sampleRate: nil,
            sampleRand: nil
        )

        // Act
        let data = spanContext.serialize()

        // Assert
        XCTAssertEqual(data["sampled"] as? Bool, false)
    }

    func testSerialization_sampledDecisionUndecided_shouldNotSerialize() {
        // Arrange
        let spanContext = SpanContext(
            trace: traceID,
            spanId: spanID,
            parentId: parentSpanID,
            operation: operation,
            sampled: .undecided,
            sampleRate: nil,
            sampleRand: nil
        )

        // Act
        let data = spanContext.serialize()

        // Assert
        XCTAssertNil(data["sampled"])
    }

    // MARK: - Assertion Helper

    private func assertContext(
        context: SpanContext,
        expectedParentSpanId: SpanId?,
        expectedOperation: String,
        expectedOrigin: String?,
        expectedSpanDescription: String?,
        expectedSampled: SentrySampleDecision,
        expectedSampleRate: NSNumber?,
        expectedSampleRand: NSNumber?,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertNotNil(context.traceId, file: file, line: line)
        XCTAssertNotNil(context.spanId, file: file, line: line)
        if let expectedParentSpanId = expectedParentSpanId {
            XCTAssertEqual(context.parentSpanId, expectedParentSpanId, file: file, line: line)
        } else {
            XCTAssertNil(context.parentSpanId, file: file, line: line)
        }

        XCTAssertEqual(context.sampled, expectedSampled, file: file, line: line)
        XCTAssertEqual(context.sampleRate, expectedSampleRate, file: file, line: line)
        XCTAssertEqual(context.sampleRand, expectedSampleRand, file: file, line: line)

        XCTAssertEqual(context.operation, expectedOperation, file: file, line: line)
        XCTAssertEqual(context.spanDescription, expectedSpanDescription, file: file, line: line)
        XCTAssertEqual(context.origin, expectedOrigin, file: file, line: line)
    }
}
