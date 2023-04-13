import Foundation

import SentryTestUtils
import XCTest

class SentryTransactionContextTests: XCTestCase {
    
    let operation = "ui.load"
    let transactionName = "Screen Load"
    let origin = "auto.ui.swift_ui"
    
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
        let traceID = SentryId()
        let spanID = SpanId()
        let parentSpanID = SpanId()
        
        let context = TransactionContext(name: transactionName, operation: operation, trace: traceID, spanId: spanID, parentSpanId: parentSpanID, parentSampled: .no)
        
        assertContext(context: context, isParentSpanIdNil: false)
        XCTAssertEqual(traceID, context.traceId)
        XCTAssertEqual(spanID, context.spanId)
        XCTAssertEqual(parentSpanID, context.parentSpanId)
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
