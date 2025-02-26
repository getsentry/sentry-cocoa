import Foundation
@testable import Sentry
import SentryTestUtils
import XCTest

class SentryTransactionContextTests: XCTestCase {
    
    private let operation = "ui.load"
    private let transactionName = "Screen Load"
    private let origin = "auto.ui.swift_ui"
    private let spanDescription = "span description"
    private let traceID = SentryId()
    private let spanID = SpanId()
    private let parentSpanID = SpanId()
    private let nameSource = SentryTransactionNameSource.route
    private let sampled = SentrySampleDecision.yes
    private let parentSampled = SentrySampleDecision.no
    private let sampleRate = NSNumber(value: 0.123456789)
    private let parentSampleRate = NSNumber(value: 0.987654321)
    private let sampleRand = NSNumber(value: 0.333)
    private let parentSampleRand = NSNumber(value: 0.666)

    // MARK: - Legacy Tests

    func testPublicInit_WithOperation() {
        let context = TransactionContext(operation: operation)
        
        assertContext(context: context, transactionName: "")
    }
    
    func testPublicInit_WithNameOperation() {
        let context = TransactionContext(name: transactionName, operation: operation)
        
        assertContext(context: context)
    }
    
    func testPublicInit_WithOperationSampled() {
        let context = TransactionContext(operation: operation, sampled: .yes)
        
        assertContext(context: context, transactionName: "", sampled: .yes)
    }

    @available(*, deprecated, message: "The test is marked as deprecated to silence the deprecation warning of the initializer")
    func testPublicInit_WithNameOperationSampled() {
        let context = TransactionContext(name: transactionName, operation: operation, sampled: .yes)
        
        assertContext(context: context, sampled: .yes)
    }

    @available(*, deprecated, message: "The test is marked as deprecated to silence the deprecation warning of the initializer")
    func testPublicInit_WithAllParams() {
        let context = TransactionContext(name: transactionName, operation: operation, trace: traceID, spanId: spanID, parentSpanId: parentSpanID, parentSampled: .no)
        
        assertContext(context: context, isParentSpanIdNil: false)
        XCTAssertEqual(traceID, context.traceId)
        XCTAssertEqual(spanID, context.spanId)
        XCTAssertEqual(parentSpanID, context.parentSpanId)
        XCTAssertEqual(.no, context.parentSampled)
    }
    
    func testPrivateInit_WithNameSourceOperationOrigin() {
        let nameSource = SentryTransactionNameSource.route
        let context = TransactionContext(name: transactionName, nameSource: nameSource, operation: operation, origin: origin)
        
        assertContext(context: context, nameSource: nameSource, origin: origin)
    }
    
    func testPrivateInit_WithNameSourceOperationOriginSampled() {
        let nameSource = SentryTransactionNameSource.route
        let sampled = SentrySampleDecision.yes
        let context = TransactionContext(name: transactionName, nameSource: nameSource, operation: operation, origin: origin, sampled: sampled, sampleRate: nil, sampleRand: nil)

        assertContext(context: context, sampled: sampled, nameSource: nameSource, origin: origin)
    }
    
    func testPrivateInit_AllParams() {
        let context = contextWithAllParams
        
        assertContext(context: context, sampled: sampled, isParentSpanIdNil: false, nameSource: nameSource, origin: origin)
        XCTAssertEqual(traceID, context.traceId)
        XCTAssertEqual(spanID, context.spanId)
        XCTAssertEqual(parentSpanID, context.parentSpanId)
    }
    
    private var contextWithAllParams: TransactionContext {
        return TransactionContext(name: transactionName, nameSource: nameSource, operation: operation, origin: origin, trace: traceID, spanId: spanID, parentSpanId: parentSpanID, sampled: sampled, parentSampled: parentSampled, sampleRate: nil, parentSampleRate: nil, sampleRand: nil, parentSampleRand: nil)
    }
    
    func testSerialize() {
        let context = contextWithAllParams
        
        let actual = context.serialize()
        XCTAssertEqual(context.traceId.sentryIdString, actual["trace_id"] as? String)
        XCTAssertEqual(context.spanId.sentrySpanIdString, actual["span_id"] as? String)
        XCTAssertEqual(context.origin, actual["origin"] as? String)
        XCTAssertEqual(context.parentSpanId?.sentrySpanIdString, actual["parent_span_id"] as? String)
        XCTAssertEqual("trace", actual["type"] as? String)
        XCTAssertEqual(true, actual["sampled"] as? NSNumber)
        XCTAssertEqual("ui.load", actual["op"] as? String)
        
        XCTAssertNotNil(actual)
    }

    // MARK: - SentryTransactionContext - Inherited Public Initializers

    func testPublicInit_WithOperation_shouldMatchExpectedContext() {
        // Act
        let context = TransactionContext(operation: operation)

        // Assert
        assertFullContext(
            context: context,
            expectedParentSpanId: nil,
            expectedOperation: operation,
            expectedOrigin: SentryTraceOrigin.manual as String,
            expectedSpanDescription: nil,
            expectedSampled: .undecided,
            expectedSampleRate: nil,
            expectedSampleRand: nil,
            expectedName: "",
            expectedNameSource: SentryTransactionNameSource.custom,
            expectedParentSampled: .undecided,
            expectedParentSampleRate: nil,
            expectedParentSampleRand: nil
        )
    }

    func testPublicInit_WithOperationSampled_shouldMatchExpectedContext() {
        // Act
        let context = TransactionContext(operation: operation, sampled: sampled)

        // Assert
        assertFullContext(
            context: context,
            expectedParentSpanId: nil,
            expectedOperation: operation,
            expectedOrigin: SentryTraceOrigin.manual as String,
            expectedSpanDescription: nil,
            expectedSampled: sampled,
            expectedSampleRate: nil,
            expectedSampleRand: nil,
            expectedName: "",
            expectedNameSource: SentryTransactionNameSource.custom,
            expectedParentSampled: .undecided,
            expectedParentSampleRate: nil,
            expectedParentSampleRand: nil
        )
    }

    func testPublicInit_WithTraceIdSpanIdParentIdOperationSampled() {
        // Act
        let context = TransactionContext(
            trace: traceID,
            spanId: spanID,
            parentId: parentSpanID,
            operation: operation,
            sampled: sampled
        )

        // Assert
        assertFullContext(
            context: context,
            expectedParentSpanId: parentSpanID,
            expectedOperation: operation,
            expectedOrigin: SentryTraceOrigin.manual as String,
            expectedSpanDescription: nil,
            expectedSampled: sampled,
            expectedSampleRate: nil,
            expectedSampleRand: nil,
            expectedName: "",
            expectedNameSource: SentryTransactionNameSource.custom,
            expectedParentSampled: .undecided,
            expectedParentSampleRate: nil,
            expectedParentSampleRand: nil
        )
    }

    // MARK: - SentryTransactionContext - Public Initializers

    func testPublicInit_WithNameOperation_shouldMatchExpectedValues() {
        // Act
        let context = TransactionContext(name: transactionName, operation: operation)
    
        // Assert
        assertFullContext(
            context: context,
            expectedParentSpanId: nil,
            expectedOperation: operation,
            expectedOrigin: SentryTraceOrigin.manual as String,
            expectedSpanDescription: nil,
            expectedSampled: .undecided,
            expectedSampleRate: nil,
            expectedSampleRand: nil,
            expectedName: transactionName,
            expectedNameSource: SentryTransactionNameSource.custom,
            expectedParentSampled: .undecided,
            expectedParentSampleRate: nil,
            expectedParentSampleRand: nil
        )
    }

    @available(*, deprecated, message: "The test is marked as deprecated to silence the deprecation warning of the initializer")
    func testPublicInit_WithNameOperationSampled_shouldMatchExpectedValues() {
        // Act
        let context = TransactionContext(name: transactionName, operation: operation, sampled: sampled)

        // Assert
        assertFullContext(
            context: context,
            expectedParentSpanId: nil,
            expectedOperation: operation,
            expectedOrigin: SentryTraceOrigin.manual as String,
            expectedSpanDescription: nil,
            expectedSampled: sampled,
            expectedSampleRate: nil,
            expectedSampleRand: nil,
            expectedName: transactionName,
            expectedNameSource: SentryTransactionNameSource.custom,
            expectedParentSampled: .undecided,
            expectedParentSampleRate: nil,
            expectedParentSampleRand: nil
        )
    }

    func testPublicInit_WithNameOperationSampledSampleRateSampleRand() {
        // Act
        let context = TransactionContext(
            name: transactionName,
            operation: operation,
            sampled: sampled,
            sampleRate: sampleRate,
            sampleRand: sampleRand
        )

        // Assert
        assertFullContext(
            context: context,
            expectedParentSpanId: nil,
            expectedOperation: operation,
            expectedOrigin: SentryTraceOrigin.manual as String,
            expectedSpanDescription: nil,
            expectedSampled: sampled,
            expectedSampleRate: sampleRate,
            expectedSampleRand: sampleRand,
            expectedName: transactionName,
            expectedNameSource: SentryTransactionNameSource.custom,
            expectedParentSampled: .undecided,
            expectedParentSampleRate: nil,
            expectedParentSampleRand: nil
        )
    }

    @available(*, deprecated, message: "The test is marked as deprecated to silence the deprecation warning of the initializer")
    func testPublicInit_WithNameTraceIdSpanIdParentSpanIdParentSampled() {
        // Act
        let context = TransactionContext(
            name: transactionName,
            operation: operation,
            trace: traceID,
            spanId: spanID,
            parentSpanId: parentSpanID,
            parentSampled: parentSampled
        )

        // Assert
        assertFullContext(
            context: context,
            expectedParentSpanId: parentSpanID,
            expectedOperation: operation,
            expectedOrigin: SentryTraceOrigin.manual as String,
            expectedSpanDescription: nil,
            expectedSampled: .undecided,
            expectedSampleRate: nil,
            expectedSampleRand: nil,
            expectedName: transactionName,
            expectedNameSource: SentryTransactionNameSource.custom,
            expectedParentSampled: parentSampled,
            expectedParentSampleRate: nil,
            expectedParentSampleRand: nil
        )
    }

    @available(*, deprecated, message: "The test is marked as deprecated to silence the deprecation warning of the initializer")
    func testPublicInit_WithNameTraceIdSpanIdParentSpanIdParentSampled_withNilValues() {
        // Act
        let context = TransactionContext(
            name: transactionName,
            operation: operation,
            trace: traceID,
            spanId: spanID,
            parentSpanId: nil,
            parentSampled: parentSampled
        )

        // Assert
        assertFullContext(
            context: context,
            expectedParentSpanId: nil,
            expectedOperation: operation,
            expectedOrigin: SentryTraceOrigin.manual as String,
            expectedSpanDescription: nil,
            expectedSampled: .undecided,
            expectedSampleRate: nil,
            expectedSampleRand: nil,
            expectedName: transactionName,
            expectedNameSource: SentryTransactionNameSource.custom,
            expectedParentSampled: parentSampled,
            expectedParentSampleRate: nil,
            expectedParentSampleRand: nil
        )
    }

    func testPublicInit_WithNameOperationTraceIdSpanIdParentSpanIdParentSampled() {
        // Act
        let context = TransactionContext(
            name: transactionName,
            operation: operation,
            trace: traceID,
            spanId: spanID,
            parentSpanId: parentSpanID,
            parentSampled: parentSampled,
            parentSampleRate: parentSampleRate,
            parentSampleRand: parentSampleRand
        )

        // Assert
        assertFullContext(
            context: context,
            expectedParentSpanId: parentSpanID,
            expectedOperation: operation,
            expectedOrigin: SentryTraceOrigin.manual as String,
            expectedSpanDescription: nil,
            expectedSampled: .undecided,
            expectedSampleRate: nil,
            expectedSampleRand: nil,
            expectedName: transactionName,
            expectedNameSource: SentryTransactionNameSource.custom,
            expectedParentSampled: parentSampled,
            expectedParentSampleRate: parentSampleRate,
            expectedParentSampleRand: parentSampleRand
        )
    }

    func testPublicInit_WithNameOperationTraceIdSpanIdParentSpanIdParentSampled_withNilValues() {
        // Act
        let context = TransactionContext(
            name: transactionName,
            operation: operation,
            trace: traceID,
            spanId: spanID,
            parentSpanId: nil,
            parentSampled: parentSampled,
            parentSampleRate: nil,
            parentSampleRand: nil
        )

        // Assert
        assertFullContext(
            context: context,
            expectedParentSpanId: nil,
            expectedOperation: operation,
            expectedOrigin: SentryTraceOrigin.manual as String,
            expectedSpanDescription: nil,
            expectedSampled: .undecided,
            expectedSampleRate: nil,
            expectedSampleRand: nil,
            expectedName: transactionName,
            expectedNameSource: SentryTransactionNameSource.custom,
            expectedParentSampled: parentSampled,
            expectedParentSampleRate: nil,
            expectedParentSampleRand: nil
        )
    }

    // MARK: - SentryTransactionContext - Private Initializers

    func testPrivateInit_WithNameSourceOperationOrigin_shouldMatchExpectedValues() {
        // Act
        let context = TransactionContext(
            name: transactionName,
            nameSource: nameSource,
            operation: operation,
            origin: origin
        )
        
        // Assert
        assertFullContext(
            context: context,
            expectedParentSpanId: nil,
            expectedOperation: operation,
            expectedOrigin: origin,
            expectedSpanDescription: nil,
            expectedSampled: .undecided,
            expectedSampleRate: nil,
            expectedSampleRand: nil,
            expectedName: transactionName,
            expectedNameSource: nameSource,
            expectedParentSampled: .undecided,
            expectedParentSampleRate: nil,
            expectedParentSampleRand: nil
        )
    }

    func testPrivateInit_WithNameSourceOperationOriginSampledSampleRateSampleRand() {
        // Act
        let context = TransactionContext(
            name: transactionName,
            nameSource: nameSource,
            operation: operation,
            origin: origin,
            sampled: sampled,
            sampleRate: sampleRate,
            sampleRand: sampleRand
        )

        // Assert
        assertFullContext(
            context: context,
            expectedParentSpanId: nil,
            expectedOperation: operation,
            expectedOrigin: origin,
            expectedSpanDescription: nil,
            expectedSampled: sampled,
            expectedSampleRate: sampleRate,
            expectedSampleRand: sampleRand,
            expectedName: transactionName,
            expectedNameSource: nameSource,
            expectedParentSampled: .undecided,
            expectedParentSampleRate: nil,
            expectedParentSampleRand: nil
        )
    }

    func testPrivateInit_WithNameSourceOperationOriginSampledSampleRateSampleRand_withNilValues() {
        // Act
        let context = TransactionContext(
            name: transactionName,
            nameSource: nameSource,
            operation: operation,
            origin: origin,
            sampled: sampled,
            sampleRate: nil,
            sampleRand: nil
        )

        // Assert
        assertFullContext(
            context: context,
            expectedParentSpanId: nil,
            expectedOperation: operation,
            expectedOrigin: origin,
            expectedSpanDescription: nil,
            expectedSampled: sampled,
            expectedSampleRate: nil,
            expectedSampleRand: nil,
            expectedName: transactionName,
            expectedNameSource: nameSource,
            expectedParentSampled: .undecided,
            expectedParentSampleRate: nil,
            expectedParentSampleRand: nil
        )
    }

    func testPrivateInit_WithNameSourceOperationOriginTraceIdSpanIdParentSpanId() {
        // Act
        let context = TransactionContext(
            name: transactionName,
            nameSource: nameSource,
            operation: operation,
            origin: origin,
            trace: traceID,
            spanId: spanID,
            parentSpanId: parentSpanID,
            parentSampled: parentSampled,
            parentSampleRate: parentSampleRate,
            parentSampleRand: parentSampleRand
        )

        // Assert
        assertFullContext(
            context: context,
            expectedParentSpanId: parentSpanID,
            expectedOperation: operation,
            expectedOrigin: origin,
            expectedSpanDescription: nil,
            expectedSampled: .undecided,
            expectedSampleRate: nil,
            expectedSampleRand: nil,
            expectedName: transactionName,
            expectedNameSource: nameSource,
            expectedParentSampled: parentSampled,
            expectedParentSampleRate: parentSampleRate,
            expectedParentSampleRand: parentSampleRand
        )
    }

    func testPrivateInit_WithNameSourceOperationOriginTraceIdSpanIdParentSpanId_withNilValues() {
        // Act
        let context = TransactionContext(
            name: transactionName,
            nameSource: nameSource,
            operation: operation,
            origin: origin,
            trace: traceID,
            spanId: spanID,
            parentSpanId: nil,
            parentSampled: parentSampled,
            parentSampleRate: nil,
            parentSampleRand: nil
        )

        // Assert
        assertFullContext(
            context: context,
            expectedParentSpanId: nil,
            expectedOperation: operation,
            expectedOrigin: origin,
            expectedSpanDescription: nil,
            expectedSampled: .undecided,
            expectedSampleRate: nil,
            expectedSampleRand: nil,
            expectedName: transactionName,
            expectedNameSource: nameSource,
            expectedParentSampled: parentSampled,
            expectedParentSampleRate: nil,
            expectedParentSampleRand: nil
        )
    }

    func testPrivateInit_WithNameSourceOperationOriginTraceIdSpanIdParentSpanIdParentSampledParentSampleRateParentSampleRand() {
        // Act
        let context = TransactionContext(
            name: transactionName,
            nameSource: nameSource,
            operation: operation,
            origin: origin,
            trace: traceID,
            spanId: spanID,
            parentSpanId: parentSpanID,
            sampled: sampled,
            parentSampled: parentSampled,
            sampleRate: sampleRate,
            parentSampleRate: parentSampleRate,
            sampleRand: sampleRand,
            parentSampleRand: parentSampleRand
        )

        // Assert
        assertFullContext(
            context: context,
            expectedParentSpanId: parentSpanID,
            expectedOperation: operation,
            expectedOrigin: origin,
            expectedSpanDescription: nil,
            expectedSampled: sampled,
            expectedSampleRate: sampleRate,
            expectedSampleRand: sampleRand,
            expectedName: transactionName,
            expectedNameSource: nameSource,
            expectedParentSampled: parentSampled,
            expectedParentSampleRate: parentSampleRate,
            expectedParentSampleRand: parentSampleRand
        )
    }

    func testPrivateInit_WithNameSourceOperationOriginTraceIdSpanIdParentSpanIdParentSampledParentSampleRateParentSampleRand_withNilValues() {
        // Act
        let context = TransactionContext(
            name: transactionName,
            nameSource: nameSource,
            operation: operation,
            origin: origin,
            trace: traceID,
            spanId: spanID,
            parentSpanId: nil,
            sampled: sampled,
            parentSampled: parentSampled,
            sampleRate: nil,
            parentSampleRate: nil,
            sampleRand: nil,
            parentSampleRand: nil
        )

        // Assert
        assertFullContext(
            context: context,
            expectedParentSpanId: nil,
            expectedOperation: operation,
            expectedOrigin: origin,
            expectedSpanDescription: nil,
            expectedSampled: sampled,
            expectedSampleRate: nil,
            expectedSampleRand: nil,
            expectedName: transactionName,
            expectedNameSource: nameSource,
            expectedParentSampled: parentSampled,
            expectedParentSampleRate: nil,
            expectedParentSampleRand: nil
        )
    }

    // MARK: - Serialization

    func testSerializeWithSampleRand() {
        // Act  
        let context = TransactionContext(
            name: transactionName,
            nameSource: nameSource,
            operation: operation,
            origin: origin,
            trace: traceID,
            spanId: spanID,
            parentSpanId: parentSpanID,
            sampled: sampled,
            parentSampled: parentSampled,
            sampleRate: sampleRate,
            parentSampleRate: parentSampleRate,
            sampleRand: sampleRand,
            parentSampleRand: parentSampleRand
        )

        // Assert
        let actual = context.serialize()
        XCTAssertEqual(context.traceId.sentryIdString, actual["trace_id"] as? String)
        XCTAssertEqual(context.spanId.sentrySpanIdString, actual["span_id"] as? String)
        XCTAssertEqual(context.origin, actual["origin"] as? String)
        XCTAssertEqual(context.parentSpanId?.sentrySpanIdString, actual["parent_span_id"] as? String)
        XCTAssertEqual("trace", actual["type"] as? String)
        XCTAssertEqual(true, actual["sampled"] as? NSNumber)
        XCTAssertEqual("ui.load", actual["op"] as? String)
        
        XCTAssertNotNil(actual)
    }

    func testSerializationWithSampleRand_minimalData_shouldNotIncludeNilValues() {
        // Arrange
        let context = TransactionContext(
            name: transactionName,
            nameSource: nameSource,
            operation: operation,
            origin: origin,
            trace: traceID,
            spanId: spanID,
            parentSpanId: nil,
            sampled: .undecided,
            parentSampled: parentSampled,
            sampleRate: nil,
            parentSampleRate: nil,
            sampleRand: nil,
            parentSampleRand: nil
        )

        // Act
        let data = context.serialize()

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

    func testSerializationWithSampleRand_NotSettingProperties_PropertiesNotSerialized() {
        // Arrange
        let context = TransactionContext(operation: operation)

        // Act
        let data = context.serialize()

        // Assert
        XCTAssertEqual(data["type"] as? String, SENTRY_TRACE_TYPE)
        XCTAssertEqual(data["trace_id"] as? String, context.traceId.sentryIdString)
        XCTAssertEqual(data["span_id"] as? String, context.spanId.sentrySpanIdString)
        XCTAssertEqual(data["op"] as? String, operation)
        XCTAssertEqual(data["origin"] as? String, "manual")
        XCTAssertNil(data["sampled"])
        XCTAssertNil(data["sample_rate"])
        XCTAssertNil(data["sample_rand"])
        XCTAssertNil(data["description"])
        XCTAssertNil(data["parent_span_id"])
    }

    func testSerializationWithSampleRand_sampledDecisionYes_shouldSerializeToTrue() {
        // Arrange
        let context = TransactionContext(
            trace: traceID,
            spanId: spanID,
            parentId: parentSpanID,
            operation: operation,
            sampled: .yes
        )

        // Act
        let data = context.serialize()

        // Assert
        XCTAssertEqual(data["sampled"] as? Bool, true)
    }

    func testSerializationWithSampleRand_sampledDecisionNo_shouldSerializeToFalse() {
        // Arrange
        let context = TransactionContext(
            trace: traceID,
            spanId: spanID,
            parentId: parentSpanID,
            operation: operation,
            sampled: .no
        )

        // Act
        let data = context.serialize()

        // Assert
        XCTAssertEqual(data["sampled"] as? Bool, false)
    }

    func testSerializationWithSampleRand_sampledDecisionUndecided_shouldNotSerialize() {
        // Arrange
        let context = TransactionContext(
            trace: traceID,
            spanId: spanID,
            parentId: parentSpanID,
            operation: operation,
            sampled: .undecided
        )

        // Act
        let data = context.serialize()

        // Assert
        XCTAssertNil(data["sampled"])
    }

    // MARK: - Assertion Helpers
    
    private func assertContext(context: TransactionContext, transactionName: String? = nil, sampled: SentrySampleDecision = .undecided, isParentSpanIdNil: Bool = true, nameSource: SentryTransactionNameSource = SentryTransactionNameSource.custom, origin: String? = nil) {
        
        XCTAssertEqual(operation, context.operation)
        XCTAssertEqual(transactionName ?? self.transactionName, context.name)
        XCTAssertEqual(sampled, context.sampled)
        XCTAssertEqual(nameSource, context.nameSource)
        XCTAssertEqual(origin ?? "manual", context.origin)
        
        XCTAssertNotNil(context.traceId)
        XCTAssertNotNil(context.spanId)
        
        if isParentSpanIdNil {
            XCTAssertNil(context.parentSpanId)
        } else {
            XCTAssertNotNil(context.parentSpanId)
        }
    }

    private func assertFullContext(
        context: TransactionContext,

        expectedParentSpanId: SpanId?,
        expectedOperation: String,
        expectedOrigin: String?,
        expectedSpanDescription: String?,
        expectedSampled: SentrySampleDecision,
        expectedSampleRate: NSNumber?,
        expectedSampleRand: NSNumber?,

        expectedName: String,
        expectedNameSource: SentryTransactionNameSource?,
        expectedParentSampled: SentrySampleDecision,
        expectedParentSampleRate: NSNumber?,
        expectedParentSampleRand: NSNumber?,

        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertNotNil(context.traceId, "Trace ID is nil", file: file, line: line)
        XCTAssertNotNil(context.spanId, "Span ID is nil", file: file, line: line)
        if let expectedParentSpanId = expectedParentSpanId {
            XCTAssertEqual(context.parentSpanId, expectedParentSpanId, "Parent Span ID is nil", file: file, line: line)
        } else {
            XCTAssertNil(context.parentSpanId, "Parent Span ID is not nil", file: file, line: line)
        }

        XCTAssertEqual(context.sampled, expectedSampled, "Sampled is not equal", file: file, line: line)
        XCTAssertEqual(context.sampleRate, expectedSampleRate, "Sample Rate is not equal", file: file, line: line)
        XCTAssertEqual(context.sampleRand, expectedSampleRand, "Sample Rand is not equal", file: file, line: line)

        XCTAssertEqual(context.operation, expectedOperation, "Operation is not equal", file: file, line: line)
        XCTAssertEqual(context.spanDescription, expectedSpanDescription, "Span Description is not equal", file: file, line: line)
        XCTAssertEqual(context.origin, expectedOrigin, "Origin is not equal", file: file, line: line)

        XCTAssertEqual(context.name, expectedName, "Name is not equal", file: file, line: line)
        XCTAssertEqual(context.nameSource, expectedNameSource, "Name Source is not equal", file: file, line: line)
        XCTAssertEqual(context.parentSampled, expectedParentSampled, "Parent Sampled is not equal", file: file, line: line)
        XCTAssertEqual(context.parentSampleRate, expectedParentSampleRate, "Parent Sample Rate is not equal", file: file, line: line)
        XCTAssertEqual(context.parentSampleRand, expectedParentSampleRand, "Parent Sample Rand is not equal", file: file, line: line)
    }
}
