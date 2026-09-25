@_spi(Private) import SentryTestUtils
@_spi(Private) @testable import Sentry
import XCTest

class SentryPerformanceTrackerTests: XCTestCase {
    
    private static let dsnAsString = TestConstants.dsnAsString(username: "SentryPerformanceTrackerTests")
    
    private class Fixture {

        let someTransaction = "Some Transaction"
        let someOperation = "Some Operation"
        let origin = "auto"
        let client: TestClient!
        let hub: TestHub
        let scope: Scope

        init() {
            scope = Scope()
            client = TestClient(options: Options())
            hub = TestHub(client: client, andScope: scope)
        }
        
        func getSut() -> SentryPerformanceTracker {
            return SentryPerformanceTracker()
        }
    }
    
    private var fixture: Fixture!
    
    override func setUp() {
        super.setUp()
        
        fixture = Fixture()
        SentrySDKInternal.setCurrentHub(fixture.hub)
    }
    
    override func tearDown() {
        super.tearDown()
        // swiftlint:disable:next avoid_clear_test_state - just disabled to allow adding the SwiftLint rule. Please double check if you can remove this when touching this.
        clearTestState()
    }
   
    func testStartSpan_CheckScopeSpan() throws {
        let sut = fixture.getSut()
        let spanId = startSpan(tracker: sut)
        
        let transaction = try XCTUnwrap(sut.getSpan(spanId) as? SentryTracer)
        
        let scopeSpan = fixture.scope.span
        
        XCTAssertIdentical(scopeSpan, transaction)
        XCTAssertTrue(Dynamic(transaction).configuration.waitForChildren.asBool ?? false)
        XCTAssertEqual(transaction.transactionContext.name, fixture.someTransaction)
        XCTAssertEqual(transaction.transactionContext.nameSource, SentryTransactionNameSource.custom)
        XCTAssertEqual(transaction.transactionContext.origin, fixture.origin)
    }
    
    func testStartSpan_ScopeAlreadyWithSpan() {
        let sut = fixture.getSut()

        let firstTransaction = SentrySDK.startTransaction(name: fixture.someTransaction, operation: fixture.someOperation, bindToScope: true)
        let spanId = startSpan(tracker: sut)
                
        let transaction = sut.getSpan(spanId)
        let scopeSpan = SentrySDKInternal.currentHub().scope.span
        
        XCTAssertNotIdentical(scopeSpan, transaction)
        XCTAssertIdentical(scopeSpan, firstTransaction)
    }

#if os(iOS) || os(tvOS)
    func testStartSpan_ScopeWithUIActionSpan_FinishesSpan() {
        let sut = fixture.getSut()
        let firstTransaction = SentrySDK.startTransaction(name: fixture.someTransaction, operation: "ui.action", bindToScope: true)
        let spanId = startSpan(tracker: sut)
                
        let transaction = sut.getSpan(spanId)
        let scopeSpan = SentrySDKInternal.currentHub().scope.span
        
        XCTAssertIdentical(scopeSpan, transaction)
        XCTAssertNotIdentical(scopeSpan, firstTransaction)
        XCTAssertTrue(firstTransaction.isFinished)
        XCTAssertEqual(.cancelled, firstTransaction.status)
    }
#endif // os(iOS) || os(tvOS)
    
    func testStartSpan_WithActiveSpan() {
        let sut = fixture.getSut()
        let spanId = startSpan(tracker: sut)
        var blockCalled = false
        
        sut.activateSpan(spanId) {
            blockCalled = true
            
            let childSpanId = self.startSpan(tracker: sut)
            
            let transaction = sut.getSpan(spanId)
            let childSpan = sut.getSpan(childSpanId)
            
            let children = Dynamic(transaction).children as [Span]?
            
            XCTAssertEqual(1, children?.count)
            XCTAssertIdentical(children!.first, childSpan)
            XCTAssertEqual(spanId, childSpan?.parentSpanId)
        }
        XCTAssertTrue(blockCalled)
    }
    
    func testActiveStack() {
        let sut = fixture.getSut()
        let spanId = startSpan(tracker: sut)
        var blockCalled = false
        
        XCTAssertNil(sut.activeSpanId())
        
        sut.activateSpan(spanId) {
            XCTAssertEqual(sut.activeSpanId(), spanId)
           
            let childSpanId = self.startSpan(tracker: sut)
            sut.activateSpan(childSpanId) {
                XCTAssertEqual(sut.activeSpanId(), childSpanId)

                let grandChildSpanId = self.startSpan(tracker: sut)
                sut.activateSpan(grandChildSpanId) {
                    XCTAssertEqual(sut.activeSpanId(), grandChildSpanId)
                    blockCalled = true
                }
                XCTAssertEqual(sut.activeSpanId(), childSpanId)
            }
            XCTAssertEqual(sut.activeSpanId(), spanId)
        }
        XCTAssertNil(sut.activeSpanId())
        XCTAssertTrue(blockCalled)
    }
    
    func testStartSpan_FromChild_CheckParent() {
        let sut = fixture.getSut()
        
        var root: Span!
        var child: Span!
        var grandchild: Span!
        
        let spanId = startSpan(tracker: sut)
        root = sut.getSpan(spanId)
        sut.activateSpan(spanId) {
            let childSpanId = self.startSpan(tracker: sut)
            child = sut.getSpan(childSpanId)
            sut.activateSpan(childSpanId) {
                let grandChildSpanId = self.startSpan(tracker: sut)
                grandchild = sut.getSpan(grandChildSpanId)
            }
        }
        XCTAssertEqual(root!.spanId, child.parentSpanId)
        XCTAssertEqual(child!.spanId, grandchild.parentSpanId)
    }
    
    func testMeasureSpanWithBlock() {
        let sut = fixture.getSut()
        var span: Span?
        
        let expect = expectation(description: "Callback Expectation")
        
        sut.measureSpan(withDescription: fixture.someTransaction, nameSource: SentryTransactionNameSource.custom.rawValue, operation: fixture.someOperation, origin: fixture.origin) {
            let spanId = sut.activeSpanId()!
            
            span = sut.getSpan(spanId)
            
            XCTAssertFalse(span!.isFinished)
            
            expect.fulfill()
        }
        
        XCTAssertNil(sut.activeSpanId())
        XCTAssertTrue(span!.isFinished)
        wait(for: [expect], timeout: 0)
    }
    
    func testMeasureSpanWithBlock_SpanNotIsAlive_BlockIsCalled() {
        let sut = fixture.getSut()
        
        let expect = expectation(description: "Callback Expectation")
        
        sut.measureSpan(withDescription: fixture.someTransaction, nameSource: SentryTransactionNameSource.custom.rawValue, operation: fixture.someOperation, origin: fixture.origin, parentSpanId: SpanId()) {
            expect.fulfill()
        }
        
        XCTAssertNil(sut.activeSpanId())
        wait(for: [expect], timeout: 0)
    }
    
    func testNotSampled() throws {
        fixture.client.options.tracesSampleRate = 0
        let sut = fixture.getSut()
        let spanId = sut.startSpan(withName: fixture.someTransaction, nameSource: SentryTransactionNameSource.custom.rawValue, operation: fixture.someOperation, origin: fixture.origin)
        let span = try XCTUnwrap(sut.getSpan(spanId))
        XCTAssertEqual(span.sampled, .no)
    }
    
    func testSampled() throws {
        fixture.client.options.tracesSampleRate = 1
        let sut = fixture.getSut()
        let spanId = sut.startSpan(withName: fixture.someTransaction, nameSource: SentryTransactionNameSource.custom.rawValue, operation: fixture.someOperation, origin: fixture.origin)
        let span = try XCTUnwrap(sut.getSpan(spanId))
        XCTAssertEqual(span.sampled, .yes)
    }
    
    func testFinishSpan() {
        let sut = fixture.getSut()
        let spanId = startSpan(tracker: sut)
        let span = sut.getSpan(spanId)
        var blockCalled = false

        XCTAssertEqual(getSpans(tracker: sut).count, 1)

        sut.activateSpan(spanId) {
            blockCalled = true
            let childId = self.startSpan(tracker: sut)
            let child = sut.getSpan(childId)
            XCTAssertEqual(self.getSpans(tracker: sut).count, 2)
            XCTAssertFalse(span!.isFinished)
            XCTAssertFalse(child!.isFinished)
            
            sut.finishSpan(childId)
            
            XCTAssertFalse(span!.isFinished)
            XCTAssertTrue(child!.isFinished)
        }

        XCTAssertEqual(getSpans(tracker: sut).count, 1)
        sut.finishSpan(spanId)
        let status = Dynamic(span).finishStatus as SentrySpanStatus?
        
        XCTAssertEqual(status!, .ok)
        XCTAssertTrue(span!.isFinished)
        XCTAssertTrue(blockCalled)
        XCTAssertEqual(getSpans(tracker: sut).count, 0)
    }
    
    func testFinishSpanWithStatus() {
        let sut = fixture.getSut()
        let spanId = startSpan(tracker: sut)
        
        let span = sut.getSpan(spanId)
        
        sut.finishSpan(spanId, with: .ok)
        
        let status = Dynamic(span).finishStatus as SentrySpanStatus?
        
        XCTAssertEqual(status!, .ok)
        XCTAssertTrue(span!.isFinished)
    }
    
    func testIsSpanAlive() {
        let sut = fixture.getSut()
        let spanId = startSpan(tracker: sut)
        var blockCalled = false
        sut.activateSpan(spanId) {
            blockCalled = true
            XCTAssertTrue(sut.isSpanAlive(spanId))
            
            let childId = self.startSpan(tracker: sut)
            XCTAssertTrue(sut.isSpanAlive(spanId))
            XCTAssertTrue(sut.isSpanAlive(childId))
            
            sut.finishSpan(childId)
            XCTAssertTrue(sut.isSpanAlive(spanId))
            XCTAssertFalse(sut.isSpanAlive(childId))
        }
        sut.finishSpan(spanId)
        XCTAssertFalse(sut.isSpanAlive(spanId))
        XCTAssertTrue(blockCalled)
    }
    
    func testActiveStackReturnNilChildSpan() {
        let sut = fixture.getSut()
        let activeSpans = Dynamic(sut).activeSpanStack as NSMutableArray?
        activeSpans?.add(TestSentrySpan())
                
        let spanId = sut.startSpan(withName: fixture.someTransaction, nameSource: SentryTransactionNameSource.custom.rawValue, operation: fixture.someOperation, origin: fixture.origin)
        
        XCTAssertEqual(spanId, SpanId.empty)
    }
        
    func testStartSpanAsync() {
        let sut = fixture.getSut()
        let spanId = startSpan(tracker: sut)
        sut.activateSpan(spanId) {
            
            let queue = DispatchQueue(label: "SentryPerformanceTrackerTests", attributes: [.concurrent, .initiallyInactive])

            let loopCount = 5_000
            let expectation = self.expectation(description: "Start spans in parallel")
            expectation.expectedFulfillmentCount = loopCount
            expectation.assertForOverFulfill = true

            for _ in 0 ..< loopCount {
                queue.async {
                    _ = self.startSpan(tracker: sut)
                    expectation.fulfill()
                }
            }
            
            queue.activate()
            self.wait(for: [expectation], timeout: 10.0)
        }
        let spans = getSpans(tracker: sut)
        XCTAssertEqual(spans.count, 5_001)
        for span in spans {
            sut.finishSpan(span.key)
        }
    }
    
    func testStackAsync() {
        let sut = fixture.getSut()
        let spanId = startSpan(tracker: sut)
        sut.activateSpan(spanId) {
            
            let queue = DispatchQueue(label: "SentryPerformanceTrackerTests", attributes: [.concurrent, .initiallyInactive])

            let loopCount = 50
            let expectation = self.expectation(description: "Create child spans in parallel")
            expectation.expectedFulfillmentCount = loopCount
            expectation.assertForOverFulfill = true

            for _ in 0 ..< loopCount {
                queue.async {
                    let childId = self.startSpan(tracker: sut)
                    sut.activateSpan(childId) {
                    }
                    expectation.fulfill()
                }
            }
            
            queue.activate()
            self.wait(for: [expectation], timeout: 10.0)
        }
        
        let stack = getStack(tracker: sut)
        XCTAssertEqual(0, stack.count)
        XCTAssertNil(sut.activeSpanId())
    }
    
    func testActivateSpan_whenSpanIdIsUnknown_shouldPreserveActiveSpanAndExecuteBlockOnce() {
        // -- Arrange --
        let sut = fixture.getSut()
        let spanId = startSpan(tracker: sut)
        let unknownSpanId = SpanId()
        var blockCalls = 0

        sut.activateSpan(spanId) {
            // -- Act --
            sut.activateSpan(unknownSpanId) {
                blockCalls += 1

                // -- Assert --
                XCTAssertEqual(sut.activeSpanId(), spanId)
            }
            XCTAssertEqual(sut.activeSpanId(), spanId)
        }
        XCTAssertEqual(blockCalls, 1)
        XCTAssertNil(sut.activeSpanId())
        XCTAssertFalse(sut.hasSpan(unknownSpanId))
    }

    func testFinishSpan_whenSpanIdIsUnknown_shouldLeaveTrackedSpansUnchanged() {
        // -- Arrange --
        let sut = fixture.getSut()
        let spanId = startSpan(tracker: sut)
        let unknownSpanId = SpanId()

        // -- Act --
        sut.finishSpan(unknownSpanId)
        sut.finishSpan(unknownSpanId, with: .cancelled)

        // -- Assert --
        XCTAssertTrue(sut.hasSpan(spanId))
        XCTAssertFalse(sut.isSpanAlive(unknownSpanId))
        XCTAssertNil(sut.getSpan(unknownSpanId))
        XCTAssertEqual(sut.getSpan(spanId)?.isFinished, false)
    }

    func testPushActiveSpan_whenSpanIdIsUnknown_shouldNotChangeStack() {
        // -- Arrange --
        let sut = fixture.getSut()
        let spanId = startSpan(tracker: sut)
        XCTAssertTrue(sut.pushActiveSpan(spanId))

        // -- Act --
        let pushed = sut.pushActiveSpan(SpanId())

        // -- Assert --
        XCTAssertFalse(pushed)
        XCTAssertEqual(sut.activeSpanId(), spanId)
        sut.popActiveSpan()
        XCTAssertNil(sut.activeSpanId())
    }

    func testFinishSpan_whenChildIsUnfinished_shouldRetainTracerUntilChildFinishes() throws {
        // -- Arrange --
        let sut = fixture.getSut()
        let parentId = startSpan(tracker: sut)
        let parent = try XCTUnwrap(sut.getSpan(parentId))
        var childId: SpanId!
        sut.activateSpan(parentId) {
            childId = self.startSpan(tracker: sut)
        }
        let child = try XCTUnwrap(sut.getSpan(childId))

        // -- Act --
        sut.finishSpan(parentId, with: .cancelled)

        // -- Assert --
        XCTAssertFalse(parent.isFinished)
        XCTAssertTrue(sut.isSpanAlive(parentId))
        XCTAssertIdentical(sut.getSpan(parentId), parent)
        XCTAssertFalse(child.isFinished)

        // -- Act --
        sut.finishSpan(childId)

        // -- Assert --
        XCTAssertTrue(child.isFinished)
        XCTAssertTrue(parent.isFinished)
        XCTAssertEqual(parent.status, .cancelled)
        XCTAssertFalse(sut.isSpanAlive(parentId))
        XCTAssertFalse(sut.isSpanAlive(childId))
    }

    func testFinishSpan_whenOnlyChildFinishes_shouldWaitForExplicitParentFinish() throws {
        // -- Arrange --
        let sut = fixture.getSut()
        let parentId = startSpan(tracker: sut)
        let parent = try XCTUnwrap(sut.getSpan(parentId))
        var childId: SpanId!
        sut.activateSpan(parentId) {
            childId = self.startSpan(tracker: sut)
        }

        // -- Act --
        sut.finishSpan(childId)

        // -- Assert --
        XCTAssertFalse(parent.isFinished)
        XCTAssertTrue(sut.isSpanAlive(parentId))
        XCTAssertFalse(sut.isSpanAlive(childId))

        // -- Act --
        sut.finishSpan(parentId)

        // -- Assert --
        XCTAssertTrue(parent.isFinished)
        XCTAssertFalse(sut.isSpanAlive(parentId))
    }

#if canImport(UIKit) && (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
    func testStartSpan_whenAppStartTraceIdExists_shouldConsumeItForFirstRootOnly() throws {
        // -- Arrange --
        let sut = fixture.getSut()
        let traceId = SentryId()
        SentryAppStartMeasurementProvider.setAppStartTrace(traceId)
        defer { SentryAppStartMeasurementProvider.setAppStartTrace(nil) }

        // -- Act --
        let firstId = startSpan(tracker: sut)
        let first = try XCTUnwrap(sut.getSpan(firstId))

        // -- Assert --
        XCTAssertEqual(first.traceId, traceId)
        XCTAssertNil(SentryAppStartMeasurementProvider.appStartTraceId())

        // -- Act --
        let secondId = startSpan(tracker: sut)
        let second = try XCTUnwrap(sut.getSpan(secondId))

        // -- Assert --
        XCTAssertNotEqual(second.traceId, traceId)
    }

    func testStartSpan_whenActiveSpanExists_shouldNotConsumeAppStartTraceId() throws {
        // -- Arrange --
        let sut = fixture.getSut()
        let parentId = startSpan(tracker: sut)
        let parent = try XCTUnwrap(sut.getSpan(parentId))
        let traceId = SentryId()
        SentryAppStartMeasurementProvider.setAppStartTrace(traceId)
        defer { SentryAppStartMeasurementProvider.setAppStartTrace(nil) }
        var childId: SpanId!

        // -- Act --
        sut.activateSpan(parentId) {
            childId = self.startSpan(tracker: sut)
        }

        // -- Assert --
        let child = try XCTUnwrap(sut.getSpan(childId))
        XCTAssertEqual(child.traceId, parent.traceId)
        XCTAssertEqual(child.parentSpanId, parentId)
        XCTAssertEqual(SentryAppStartMeasurementProvider.appStartTraceId(), traceId)
    }
#endif

    private func getSpans(tracker: SentryPerformanceTracker) -> [SpanId: Span] {
        let result = Dynamic(tracker).spans as [SpanId: Span]?
        return result!
    }
    
    private func getStack(tracker: SentryPerformanceTracker) -> [Span] {
        let result = Dynamic(tracker).activeSpanStack as [Span]?
        return result!
    }
    
    private func startSpan(tracker: SentryPerformanceTracker) -> SpanId {
        return tracker.startSpan(withName: fixture.someTransaction, nameSource: SentryTransactionNameSource.custom.rawValue, operation: fixture.someOperation, origin: fixture.origin)
    }
        
}
