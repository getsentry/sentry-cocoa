#if canImport(UIKit) && canImport(SwiftUI)
@testable import Sentry
import SentryInternal
@testable import SentrySwiftUI
import XCTest

class SentryTraceViewModelTestCase: XCTestCase {

    override func tearDown() {
        super.tearDown()
        SentryPerformanceTracker.shared.clear()
    }
    
    func testCreateTransaction() throws {
        let option = Options()
        SentrySDKInternal.setCurrentHub(SentryHub(client: SentryClient(options: option), andScope: nil))
        
        let viewModel = SentryTraceViewModel(name: "TestView", nameSource: .component, waitForFullDisplay: false)
        let spanId = viewModel.startSpan()

        let tracer = try XCTUnwrap(SentrySDK.span as? SentryTracer)
        
        XCTAssertEqual(tracer.transactionContext.name, "TestView")
        XCTAssertEqual(tracer.children.first?.spanId, spanId)
        XCTAssertEqual(tracer.children.first?.spanDescription, "TestView - body")
    }
    
    func testRootTransactionStarted() throws {
        let option = Options()
        SentrySDKInternal.setCurrentHub(SentryHub(client: SentryClient(options: option), andScope: nil))
        
        let viewModel = SentryTraceViewModel(name: "RootTransactionTest", nameSource: .component, waitForFullDisplay: true)
        _ = viewModel.startSpan()
        
        let tracer = try XCTUnwrap(SentrySDK.span as? SentryTracer)
        XCTAssertEqual(tracer.transactionContext.name, "RootTransactionTest")
        XCTAssertEqual(tracer.transactionContext.operation, "ui.load")
        XCTAssertEqual(tracer.transactionContext.origin, "auto.ui.swift_ui")
    }
    
    func testNoRootTransactionForCurrentTransactionRunning() throws {
        let option = Options()
        SentrySDKInternal.setCurrentHub(SentryHub(client: SentryClient(options: option), andScope: nil))
        
        let testSpan = SentryPerformanceTracker.shared.startSpan(withName: "Test Root", nameSource: .component, operation: "Testing", origin: "Test")
        SentryPerformanceTracker.shared.pushActiveSpan(testSpan)
        
        let viewModel = SentryTraceViewModel(name: "ViewContent",
                                             nameSource: .component,
                                             waitForFullDisplay: true)
        _ = viewModel.startSpan()
        
        let tracer = try XCTUnwrap(SentrySDK.span as? SentryTracer)
        XCTAssertEqual(tracer.transactionContext.name, "Test Root")
        XCTAssertEqual(tracer.children.count, 1)
        XCTAssertEqual(tracer.children.first?.spanDescription, "ViewContent")
    }
       
    func testNoTransactionWhenViewAppeared() {
        let option = Options()
        SentrySDKInternal.setCurrentHub(SentryHub(client: SentryClient(options: option), andScope: nil))
        
        let viewModel = SentryTraceViewModel(name: "TestView", nameSource: .component, waitForFullDisplay: false)
        viewModel.viewDidAppear()
        
        let spanId = viewModel.startSpan()
        XCTAssertNil(spanId, "Span should not be created if the view has already appeared.")
    }
    
    func testFinishSpan() throws {
        let option = Options()
        SentrySDKInternal.setCurrentHub(SentryHub(client: SentryClient(options: option), andScope: nil))
        
        let viewModel = SentryTraceViewModel(name: "FinishSpanTest", nameSource: .component, waitForFullDisplay: false)
        let spanId = try XCTUnwrap(viewModel.startSpan())
        XCTAssertNotNil(spanId, "Span should be created.")
        
        let tracer = try XCTUnwrap(SentrySDK.span as? SentryTracer)
        
        viewModel.finishSpan(spanId)
        viewModel.viewDidAppear()

        // The span is finished in the next main cycle, therefore we need to wait for it.
        let expectation = XCTestExpectation(description: "Wait for span to be finished.")
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.5)

        // Verify that the span was popped and finished
        XCTAssertNil(SentryPerformanceTracker.shared.activeSpanId(), "Active span should be nil after finishing the span.")
        
        XCTAssertTrue(tracer.isFinished, "The transaction should be finished.")
        XCTAssertTrue(tracer.children.first?.isFinished == true, "The body span should be finished")
    }
    
    func testUseWaitForFullDisplayFromOptions() throws {
        let option = Options()
        option.enableTimeToFullDisplayTracing = true
        SentrySDKInternal.setStart(with: option)
               
        let viewModel = SentryTraceViewModel(name: "FinishSpanTest", nameSource: .component, waitForFullDisplay: nil)
        XCTAssertTrue(viewModel.waitForFullDisplay)
    }
    
    func testUseWaitForFullDisplayFromParameter() throws {
        let option = Options()
        option.enableTimeToFullDisplayTracing = true
        SentrySDKInternal.setStart(with: option)
               
        let viewModel = SentryTraceViewModel(name: "FinishSpanTest", nameSource: .component, waitForFullDisplay: false)
        XCTAssertFalse(viewModel.waitForFullDisplay)
    }
}

#endif
