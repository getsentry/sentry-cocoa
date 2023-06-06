import Foundation
import SentryTestUtils
import XCTest

class SentryTransactionContextTests: XCTestCase {
    
    let operation = "ui.load"
    let transactionName = "Screen Load"
    let origin = "auto.ui.swift_ui"
    let traceID = SentryId()
    let spanID = SpanId()
    let parentSpanID = SpanId()
    let nameSource = SentryTransactionNameSource.route
    let sampled = SentrySampleDecision.yes
    let parentSampled = SentrySampleDecision.no
    
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
    
    func testPublicInit_WithNameOperationSampled() {
        let context = TransactionContext(name: transactionName, operation: operation, sampled: .yes)
        
        assertContext(context: context, sampled: .yes)
    }
    
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
        let context = TransactionContext(name: transactionName, nameSource: nameSource, operation: operation, origin: origin, sampled: sampled)
        
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
        return TransactionContext(name: transactionName, nameSource: nameSource, operation: operation, origin: origin, trace: traceID, spanId: spanID, parentSpanId: parentSpanID, sampled: sampled, parentSampled: parentSampled)
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
}
