import _SentryPrivate
@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

// swiftlint:disable file_length
// We are aware that the tracer has a lot of logic and we should maybe
// move some of it to other classes.
class SentryTracerTests: XCTestCase {
    
    private class TracerDelegate: SentryTracerDelegate {

        var activeSpan: Span?

        func getActiveSpan() -> (any Span)? {
            return activeSpan
        }

        var tracerDidFinishCalled = false
        func tracerDidFinish(_ tracer: SentryTracer) {
            tracerDidFinishCalled = true
        }
    }

    private class Fixture {
        let client: TestClient!
        let hub: TestHub
        let scope: Scope
        let dispatchQueue = TestSentryDispatchQueueWrapper()
        let debugImageProvider = TestDebugImageProvider()
        
        let transactionName = "Some Transaction"
        let transactionOperation = "ui.load"
        var transactionContext: TransactionContext!
        
        let appStartWarmOperation = "app.start.warm"
        let appStartColdOperation = "app.start.cold"
        
        let currentDateProvider = TestCurrentDateProvider()
        var appStart: Date
        lazy var appStartSystemTime = currentDateProvider.systemTime()
        var appStartEnd: Date
        var appStartDuration = 0.5
        let testKey = "extra_key"
        let testValue = "extra_value"
        
        let idleTimeout: TimeInterval = 1.0
        
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        var displayLinkWrapper: TestDisplayLinkWrapper
#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        
        init() {
            SentryDependencyContainer.sharedInstance().dateProvider = currentDateProvider
            SentryDependencyContainer.sharedInstance().dispatchQueueWrapper = dispatchQueue
            SentryDependencyContainer.sharedInstance().application = TestSentryApplication()

            debugImageProvider.debugImages = [TestData.debugImage]
            SentryDependencyContainer.sharedInstance().debugImageProvider = debugImageProvider
            appStart = currentDateProvider.date()
            appStartEnd = appStart.addingTimeInterval(appStartDuration)
            
            transactionContext = TransactionContext(name: transactionName, operation: transactionOperation)
            
            scope = Scope()
            client = TestClient(options: Options())
            client.options.tracesSampleRate = 1
            hub = TestHub(client: client, andScope: scope)
            
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
            displayLinkWrapper = TestDisplayLinkWrapper(dateProvider: currentDateProvider)
            
            SentryDependencyContainer.sharedInstance().framesTracker.setDisplayLinkWrapper(displayLinkWrapper)
            SentryDependencyContainer.sharedInstance().framesTracker.start()
            displayLinkWrapper.call()
#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        }

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        func getAppStartMeasurement(type: SentryAppStartType, preWarmed: Bool = false) -> SentryAppStartMeasurement {
            let runtimeInitDuration = 0.05
            let runtimeInit = appStart.addingTimeInterval(runtimeInitDuration)
            let mainDuration = 0.15
            let main = appStart.addingTimeInterval(mainDuration)
            let sdkStart = appStart.addingTimeInterval(0.1)
            let didFinishLaunching = appStart.addingTimeInterval(0.2)
            appStart = preWarmed ? main : appStart
            appStartDuration = preWarmed ? appStartDuration - runtimeInitDuration - mainDuration : appStartDuration

            appStartEnd = appStart.addingTimeInterval(appStartDuration)

            return SentryAppStartMeasurement(type: type, isPreWarmed: preWarmed, appStartTimestamp: appStart, runtimeInitSystemTimestamp: appStartSystemTime, duration: appStartDuration, runtimeInitTimestamp: runtimeInit, moduleInitializationTimestamp: main, sdkStartTimestamp: sdkStart, didFinishLaunchingTimestamp: didFinishLaunching)
        }
        #endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        
        func getSut(waitForChildren: Bool = true, idleTimeout: TimeInterval = 0.0, finishMustBeCalled: Bool = false) -> SentryTracer {
            let tracer = hub.startTransaction(
                with: transactionContext,
                bindToScope: false,
                customSamplingContext: [:],
                configuration: SentryTracerConfiguration(block: {
                    $0.waitForChildren = waitForChildren
                    $0.idleTimeout = idleTimeout
                    $0.finishMustBeCalled = finishMustBeCalled
                }))
            return tracer
        }
    }
    
    private var fixture: Fixture!
    
    override func setUp() {
        super.setUp()
        fixture = Fixture()
    }
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }
    
    /**`
     * This test makes sure that the span has a weak reference to the tracer and doesn't call the
     * tracer#spanFinished method.
     */
    func testSpanFinishesAfterTracerReleased_NoCrash_TracerIsNil() {
        var child: Span?
        // To make sure the tracer is deallocated.
        autoreleasepool {
            let hub = TestHub(client: nil, andScope: nil)
            let context = TransactionContext(operation: "")
            let tracer = SentryTracer(transactionContext: context, hub: hub, configuration: SentryTracerConfiguration(block: { configuration in
                configuration.waitForChildren = true
            }))
            
            tracer.finish()
            child = tracer.startChild(operation: "child")
        }
        
        XCTAssertNotNil(child)
        child?.finish()
    }
    
    func testFinish_WithChildren_WaitsForAllChildren() throws {
        let sut = fixture.getSut()
        let child = sut.startChild(operation: fixture.transactionOperation)
        sut.finish()
        
        assertTransactionNotCaptured(sut)
        
        let grandChild = child.startChild(operation: fixture.transactionOperation)
        child.finish()
        
        assertTransactionNotCaptured(sut)
        
        let granGrandChild = grandChild.startChild(operation: fixture.transactionOperation)
        
        granGrandChild.finish()
        assertTransactionNotCaptured(sut)
        
        grandChild.finish()
        
        assertOneTransactionCaptured(sut)
        
        let serialization = try getSerializedTransaction()
        let spans = try XCTUnwrap(serialization["spans"]! as? [[String: Any]])
        
        let tracerTimestamp: NSDate = sut.timestamp! as NSDate
        
        XCTAssertEqual(spans.count, 3)
        XCTAssertEqual(tracerTimestamp.timeIntervalSince1970, serialization["timestamp"] as? TimeInterval)
        
        for span in spans {
            XCTAssertEqual(tracerTimestamp.timeIntervalSince1970, span["timestamp"] as? TimeInterval)
        }
    }
    
    func testFinish_ShouldIgnoreWaitForChildrenCallback() throws {
        let sut = fixture.getSut()
        
        sut.shouldIgnoreWaitForChildrenCallback = { _ in
            return true
        }
        let child = sut.startChild(operation: fixture.transactionOperation)
        sut.finish()
        
        XCTAssertEqual(child.status, .deadlineExceeded)
        
        assertOneTransactionCaptured(sut)
    
        let serialization = try getSerializedTransaction()
        let spans = try XCTUnwrap(serialization["spans"]! as? [[String: Any]])
        
        let tracerTimestamp: NSDate = sut.timestamp! as NSDate
        
        XCTAssertEqual(spans.count, 1)
        let span = try XCTUnwrap(spans.first, "Expected first span not to be nil")
        XCTAssertEqual(span["timestamp"] as? TimeInterval, tracerTimestamp.timeIntervalSince1970)
        
        XCTAssertNotNil(sut.shouldIgnoreWaitForChildrenCallback, "We must not set the callback to nil because when iterating over the child spans in hasUnfinishedChildSpansToWaitFor this could lead to a crash when shouldIgnoreWaitForChildrenCallback is nil.")
    }
    
    /// Reproduces a crash in hasUnfinishedChildSpansToWaitFor; see https://github.com/getsentry/sentry-cocoa/issues/3781
    /// We used to set the shouldIgnoreWaitForChildrenCallback to nil in finishInternal, which can lead
    /// to a crash when spans keep finishing while finishInternal is executed because
    /// shouldIgnoreWaitForChildrenCallback could be then nil in hasUnfinishedChildSpansToWaitFor.
    func testFinish_ShouldIgnoreWaitForChildrenCallback_DoesNotCrash() throws {
        for _ in 0..<5 {
            let sut = fixture.getSut()

            let dispatchQueue = DispatchQueue(label: "test", attributes: [.concurrent, .initiallyInactive])

            let expectation = expectation(description: "call everything")
            expectation.expectedFulfillmentCount = 11

            sut.shouldIgnoreWaitForChildrenCallback = { _ in
                return true
            }

            for _ in 0..<1_000 {
                let child = sut.startChild(operation: self.fixture.transactionOperation)
                child.finish()
            }

            dispatchQueue.async {
                for _ in 0..<10 {
                    let child = sut.startChild(operation: self.fixture.transactionOperation)
                    child.finish()
                    expectation.fulfill()
                }
            }
            dispatchQueue.async {
                sut.finish()
                expectation.fulfill()
            }

            dispatchQueue.activate()
            wait(for: [expectation], timeout: 1.0)
        }
    }

    func testDeadlineTimerout_FinishesTransactionAndChildren() throws {
        let sut = fixture.getSut()
        
        let child1 = sut.startChild(operation: fixture.transactionOperation)
        let child2 = sut.startChild(operation: fixture.transactionOperation)
        let child3 = sut.startChild(operation: fixture.transactionOperation)

        child3.finish()

        fixture.dispatchQueue.invokeLastDispatchAfter()

        assertOneTransactionCaptured(sut)

        XCTAssertEqual(sut.status, .deadlineExceeded)
        XCTAssertEqual(child1.status, .deadlineExceeded)
        XCTAssertEqual(child2.status, .deadlineExceeded)
        XCTAssertEqual(child3.status, .ok)
    }
    
    func testCancelDeadlineTimeout_TracerDeallocated() throws {

        weak var weakSut: SentryTracer?
        
        // Added internal function so the tracer gets deallocated after executing this function.
        func startTracer() throws {
            let sut = fixture.getSut()
            
            weakSut = sut
            
            // The TestHub keeps a reference to the tracer in capturedEventsWithScopes.
            // We set it to nil to avoid that.
            sut.hub = nil
        }
        try startTracer()
        
        XCTAssertNil(weakSut, "sut was not deallocated")

        XCTAssertEqual(1, fixture.dispatchQueue.dispatchCancelInvocations, "Expected one cancel invocation for the deadline timeout.")
    }
    
    func testDeadlineTimeout_FiresAfterTracerDeallocated() throws {
        // Added internal function so the tracer gets deallocated after executing this function.
        func startTracer() {
            _ = fixture.getSut()
        }
        startTracer()

        fixture.dispatchQueue.invokeLastDispatchAfter()
    }
    
    func testDeadlineTimoutForManualTransaction_NoDeadlineTimeoutQueued() {
        let sut = fixture.getSut(waitForChildren: false, idleTimeout: 0.0)
        
        let invocationsBeforeFinish = fixture.dispatchQueue.dispatchAfterInvocations.count
        
        sut.finish()
        
        let invocationsAfterFinish = fixture.dispatchQueue.dispatchAfterInvocations.count
        
        XCTAssertEqual(invocationsBeforeFinish, invocationsAfterFinish)
    }

    func testFramesofSpans_SetsDebugMeta() {
        let sut = fixture.getSut()
        sut.frames = [TestData.mainFrame, TestData.testFrame]

        let debugImageProvider = TestDebugImageProvider()
        debugImageProvider.debugImages = [TestData.debugImage]
        SentryDependencyContainer.sharedInstance().debugImageProvider = debugImageProvider

        let transaction = Dynamic(sut).toTransaction().asObject as? Transaction

        XCTAssertEqual(transaction?.debugMeta?.count ?? 0, 1)
        XCTAssertEqual(transaction?.debugMeta?.first, TestData.debugImage)
        XCTAssertEqual(1, debugImageProvider.getDebugImagesFromCacheForFramesInvocations.count, "Tracer must retrieve debug images from cache.")
    }

    func testDeadlineTimeout_ForAutoTransaction_FinishesChildSpans() throws {
        let sut = fixture.getSut(idleTimeout: fixture.idleTimeout)
        let child1 = sut.startChild(operation: fixture.transactionOperation)
        let child2 = sut.startChild(operation: fixture.transactionOperation)
        let child3 = sut.startChild(operation: fixture.transactionOperation)

        child3.finish()

        fixture.dispatchQueue.invokeLastDispatchAfter()

        XCTAssertEqual(sut.status, .deadlineExceeded)
        XCTAssertEqual(child1.status, .deadlineExceeded)
        XCTAssertEqual(child2.status, .deadlineExceeded)
        XCTAssertEqual(child3.status, .ok)
    }
    
    func testDeadlineTimeout_ForManualTransactions_DoesNotFinishChildSpans() throws {
        let sut = fixture.getSut(waitForChildren: false)
        let child1 = sut.startChild(operation: fixture.transactionOperation)
        let child2 = sut.startChild(operation: fixture.transactionOperation)
        let child3 = sut.startChild(operation: fixture.transactionOperation)

        child3.finish()

        XCTAssertEqual(0, fixture.dispatchQueue.dispatchAfterInvocations.count)

        XCTAssertEqual(sut.status, .undefined)
        XCTAssertEqual(child1.status, .undefined)
        XCTAssertEqual(child2.status, .undefined)
        XCTAssertEqual(child3.status, .ok)
    }

    func testDeadlineTimeout_Finish_CancelsDeadlineTimeout() {
        let sut = fixture.getSut()
        sut.finish()
        
        XCTAssertEqual(1, fixture.dispatchQueue.dispatchCancelInvocations, "Excpected one cancel invocation for the deadline timeout.")
    }
    
    func testDeadlineTimer_MultipleSpansFinishedInParallel() {
        SentryDependencyContainer.sharedInstance().dispatchQueueWrapper = SentryDispatchQueueWrapper()
        let sut = fixture.getSut(idleTimeout: 0.01)
        
        testConcurrentModifications(writeWork: { _ in
            let child = sut.startChild(operation: self.fixture.transactionOperation)
            child.finish()
        })
        SentryDependencyContainer.sharedInstance().dispatchQueueWrapper = fixture.dispatchQueue
    }

    func testFinish_CheckDefaultStatus() throws {
        let sut = fixture.getSut()
        sut.finish()
        fixture.dispatchQueue.invokeLastDispatchAfter()
        XCTAssertEqual(sut.status, .ok)
    }
    
    func testIdleTransactionWithStatus_KeepsStatusWhenAutoFinishing() {
        let status = SentrySpanStatus.aborted
        let sut = fixture.getSut(idleTimeout: fixture.idleTimeout)
        sut.status = status
        
        let child = sut.startChild(operation: fixture.transactionOperation)
        advanceTime(bySeconds: 0.1)
        child.finish()
        
        fixture.dispatchQueue.invokeLastDispatchAfter()
        
        assertOneTransactionCaptured(sut)
        XCTAssertEqual(status, sut.status)
    }
    
    func testIdleTransaction_CreatingDispatchBlockFails_NoTransactionCaptured() {
        fixture.dispatchQueue.createDispatchBlockReturnsNULL = true
        
        let sut = fixture.getSut(idleTimeout: fixture.idleTimeout)
        
        assertTransactionNotCaptured(sut)
    }
    
    func testIdleTransaction_CreatingDispatchBlockFailsForFirstChild_FinishesTransaction() {
        let sut = fixture.getSut(idleTimeout: fixture.idleTimeout)
        
        fixture.dispatchQueue.createDispatchBlockReturnsNULL = true
        
        let child = sut.startChild(operation: fixture.transactionOperation)
        advanceTime(bySeconds: 0.1)
        child.finish()
        
        assertOneTransactionCaptured(sut)
    }
    
    func testWaitForChildrenTransactionWithStatus_OverwriteStatusInFinish() {
        let sut = fixture.getSut()
        sut.status = .aborted
        
        let finishstatus = SentrySpanStatus.cancelled
        
        let child = sut.startChild(operation: fixture.transactionOperation)
        advanceTime(bySeconds: 0.1)
        child.finish()
        
        sut.finish(status: finishstatus)
        
        assertOneTransactionCaptured(sut)
        XCTAssertEqual(finishstatus, sut.status)
    }
    
    func testManualTransaction_OverwritesStatusInFinish() {
        let sut = fixture.getSut(waitForChildren: false)
        sut.status = .aborted
        
        sut.finish()
        
        assertOneTransactionCaptured(sut)
        XCTAssertEqual(.ok, sut.status)
    }
    
    func testFinish_WithoutHub_DoesntCaptureTransaction() {
        let sut = SentryTracer(transactionContext: fixture.transactionContext, hub: nil)
        
        sut.finish()
        
        XCTAssertEqual(0, fixture.hub.capturedEventsWithScopes.count)
    }
    
    func testFinish_WaitForAllChildren_ExceedsMaxDuration_NoTransactionCaptured() {
        let sut = fixture.getSut()
        
        advanceTime(bySeconds: 500)
        
        sut.finish()
        
        assertTransactionNotCaptured(sut)
    }
    
    func testFinish_WaitForAllChildren_DoesNotExceedsMaxDuration_TransactionCaptured() {
        let sut = fixture.getSut()
        
        advanceTime(bySeconds: 499.9)
        
        sut.finish()
        
        assertOneTransactionCaptured(sut)
    }

    #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    func testFinish_WaitForAllChildren_StartTimeModified_NoTransactionCaptured() {
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .cold)
        SentrySDKInternal.setAppStartMeasurement(appStartMeasurement)
        advanceTime(bySeconds: 1)
        
        let sut = fixture.getSut()
        advanceTime(bySeconds: 499)
        
        sut.finish()
        
        assertTransactionNotCaptured(sut)
    }
    #endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    
    func testFinish_IdleTimeout_ExceedsMaxDuration_NoTransactionCaptured() {
        let sut = fixture.getSut(idleTimeout: fixture.idleTimeout)
        
        advanceTime(bySeconds: 500)
        
        sut.finish()
        
        assertTransactionNotCaptured(sut)
    }
    
    func testIdleTimeout_NoChildren_TransactionNotCaptured() {
        _ = fixture.getSut(idleTimeout: fixture.idleTimeout)
        
        fixture.dispatchQueue.invokeLastDispatchAfter()
        
        XCTAssertEqual(0, fixture.hub.capturedEventsWithScopes.count)
    }
    
    func testIdleTimeout_NoChildren_SpanOnScopeUnset() {
        let sut = fixture.getSut(idleTimeout: fixture.idleTimeout)
        
        fixture.hub.scope.span = sut
        
        fixture.dispatchQueue.invokeLastDispatchAfter()
        
        XCTAssertNil(fixture.hub.scope.span)
    }
    
    func testIdleTimeout_InvokesDispatchAfterWithCorrectWhen() {
        _ = fixture.getSut(idleTimeout: fixture.idleTimeout)
        
        fixture.dispatchQueue.invokeLastDispatchAfter()
        
        XCTAssertEqual(fixture.idleTimeout, fixture.dispatchQueue.dispatchAfterInvocations.invocations.first?.interval)
    }
    
    func testIdleTimeout_SpanAdded_IdleTimeoutCancelled() {
        let sut = fixture.getSut(idleTimeout: fixture.idleTimeout)
        
        sut.startChild(operation: fixture.transactionOperation)
        
        XCTAssertEqual(2, fixture.dispatchQueue.dispatchAfterInvocations.count, "Expected two dispatchAfter invocations one for the idle timeout and one for the deadline timer.")
        XCTAssertEqual(1, fixture.dispatchQueue.dispatchCancelInvocations, "Expected one cancel invocation for the idle timeout.")
    }
    
    func testIdleTimeoutWithRealDispatchQueue_SpanAdded_IdleTimeoutCancelled() {
        SentryDependencyContainer.sharedInstance().dispatchQueueWrapper = SentryDispatchQueueWrapper()
        let sut = fixture.getSut(idleTimeout: 0.1)
        
        let child = sut.startChild(operation: fixture.transactionOperation)
        let grandChild = child.startChild(operation: fixture.transactionOperation)
        grandChild.finish()
        child.finish()
        
        delayNonBlocking(timeout: 0.5)
        
        assertOneTransactionCaptured(sut)
        SentryDependencyContainer.sharedInstance().dispatchQueueWrapper = fixture.dispatchQueue
    }
    
    func testIdleTimeout_TwoChildren_FirstFinishes_WaitsForTheOther() {
        let sut = fixture.getSut(idleTimeout: fixture.idleTimeout)
        
        let child1 = sut.startChild(operation: fixture.transactionOperation)
        let child2 = sut.startChild(operation: fixture.transactionOperation)
        
        XCTAssertEqual(2, fixture.dispatchQueue.dispatchAfterInvocations.count)
        child1.finish()
        XCTAssertEqual(2, fixture.dispatchQueue.dispatchAfterInvocations.count)
        
        child2.finish()
        XCTAssertEqual(3, fixture.dispatchQueue.dispatchAfterInvocations.count)
        
        fixture.dispatchQueue.invokeLastDispatchAfter()
        
        assertOneTransactionCaptured(sut)
    }
    
    func testIdleTimeout_ChildSpanFinished_IdleStarted() {
        let sut = fixture.getSut(idleTimeout: fixture.idleTimeout)
        XCTAssertEqual(2, fixture.dispatchQueue.dispatchAfterInvocations.count)
        
        let child = sut.startChild(operation: fixture.transactionOperation)
        XCTAssertEqual(1, fixture.dispatchQueue.dispatchCancelInvocations)
        
        child.finish()
        XCTAssertEqual(3, fixture.dispatchQueue.dispatchAfterInvocations.count)

        // The grandchild is a NoOp span
        let grandChild = child.startChild(operation: fixture.transactionOperation)
        XCTAssertEqual(3, fixture.dispatchQueue.dispatchCancelInvocations)
        
        grandChild.finish()
        XCTAssertEqual(4, fixture.dispatchQueue.dispatchAfterInvocations.count)
        XCTAssertEqual(4, fixture.dispatchQueue.dispatchCancelInvocations)
        
        fixture.dispatchQueue.invokeLastDispatchAfter()
        
        assertOneTransactionCaptured(sut)
    }
    
    func testIdleTimeout_TimesOut_TrimsEndTimestamp() {
        let sut = fixture.getSut(idleTimeout: fixture.idleTimeout)
        
        let child1 = sut.startChild(operation: fixture.transactionOperation)
        advanceTime(bySeconds: 1.0)
        child1.finish()
        
        let child2 = sut.startChild(operation: fixture.transactionOperation)
        advanceTime(bySeconds: 1.0)
        let expectedEndTimestamp = fixture.currentDateProvider.date()
        child2.finish()
        
        advanceTime(bySeconds: fixture.idleTimeout)
        fixture.dispatchQueue.invokeLastDispatchAfter()
        
        assertOneTransactionCaptured(sut)
        XCTAssertEqual(expectedEndTimestamp, sut.timestamp)
    }
    
    func testIdleTimeout_CallFinish_TrimsEndTimestamp() {
        let sut = fixture.getSut(idleTimeout: fixture.idleTimeout)
        
        let child = sut.startChild(operation: fixture.transactionOperation)
        advanceTime(bySeconds: 1.0)
        child.finish()
        let expectedEndTimestamp = fixture.currentDateProvider.date()
        
        advanceTime(bySeconds: 1.0)
        sut.finish(status: .cancelled)
        
        assertOneTransactionCaptured(sut)
        XCTAssertEqual(expectedEndTimestamp, sut.timestamp)
    }
    
    func testIdleTimeout_TracerDeallocated() throws {
#if !os(tvOS) && !os(watchOS)
        if sentry_threadSanitizerIsPresent() {
            throw XCTSkip("doesn't currently work with TSAN enabled. the tracer instance remains retained by something in the TSAN dylib, and we cannot debug the memory graph with TSAN attached to see what is retaining it. it's likely out of our control.")
        }
#endif // !os(tvOS) && !os(watchOS)
        
        // Interact with sut in extra function so ARC deallocates it
        func getSut() {
            let sut = fixture.getSut(idleTimeout: fixture.idleTimeout)
            
            _ = sut.startChild(operation: fixture.transactionOperation)
        }
        
        getSut()
            
        // dispatch the idle timeout block manually
        for dispatchAfterBlock in fixture.dispatchQueue.dispatchAfterInvocations.invocations {
            dispatchAfterBlock.block()
        }
        
        XCTAssertEqual(0, fixture.hub.capturedEventsWithScopes.count)
    }
    
    func testAutomaticTransaction_CallFinish_DoesNotTrimEndTimestamp() {
        let sut = fixture.getSut(waitForChildren: false)
        
        advanceTime(bySeconds: 1.0)
        let child = sut.startChild(operation: fixture.transactionOperation)
        child.finish()
        advanceTime(bySeconds: 1.0)
        
        let expectedEndTimestamp = fixture.currentDateProvider.date()
        sut.finish()
        
        assertOneTransactionCaptured(sut)
        XCTAssertEqual(expectedEndTimestamp, sut.timestamp)
    }
    
    func testIdleTimeoutWithUnfinishedChildren_TimesOut_TrimsEndTimestamp() {
        let sut = fixture.getSut(idleTimeout: fixture.idleTimeout)
        
        let child1 = sut.startChild(operation: fixture.transactionOperation)
        advanceTime(bySeconds: 1.0)
        child1.finish()
        advanceTime(bySeconds: 1.0)
        _ = sut.startChild(operation: fixture.transactionOperation)
        
        advanceTime(bySeconds: fixture.idleTimeout)
        
        fixture.dispatchQueue.invokeLastDispatchAfter()
        let expectedEndTimestamp = fixture.currentDateProvider.date()
        
        assertOneTransactionCaptured(sut)
        XCTAssertEqual(expectedEndTimestamp, sut.timestamp)
    }
    
    func testIdleTimeout_CallFinish_WaitsForChildren_DoesntStartTimeout() {
        let sut = fixture.getSut(idleTimeout: fixture.idleTimeout)
        
        let child = sut.startChild(operation: fixture.transactionOperation)
        XCTAssertEqual(2, fixture.dispatchQueue.dispatchAfterInvocations.count)
        
        sut.finish()
        XCTAssertEqual(1, fixture.dispatchQueue.dispatchCancelInvocations)
        XCTAssertEqual(2, fixture.dispatchQueue.dispatchAfterInvocations.count)
        
        XCTAssertFalse(sut.isFinished)
        advanceTime(bySeconds: 1)
        child.finish()
        
        XCTAssertEqual(2, fixture.dispatchQueue.dispatchAfterInvocations.count)
        
        XCTAssertTrue(sut.isFinished)
    }

    #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    func testAddColdAppStartMeasurement_PutOnNextAutoUITransaction() throws {
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .cold)
        SentrySDKInternal.setAppStartMeasurement(appStartMeasurement)
        
        whenFinishingAutoUITransaction(startTimestamp: 5)

        try assertMeasurements(["app_start_cold": ["value": fixture.appStartDuration * 1_000]])

        let transaction = try XCTUnwrap(fixture.hub.capturedEventsWithScopes.first!.event as? Transaction)
        assertAppStartsSpanAdded(transaction: transaction, startType: "Cold Start", operation: fixture.appStartColdOperation, appStartMeasurement: appStartMeasurement)
    }
    #endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

    func test_startChildWithDelegate() {
        let delegate = TracerDelegate()

        let sut = fixture.getSut()
        sut.delegate = delegate

        let child = sut.startChild(operation: fixture.transactionOperation)

        delegate.activeSpan = child

        let secondChild = sut.startChild(operation: fixture.transactionOperation)

        XCTAssertEqual(secondChild.parentSpanId, child.spanId)
    }

    func test_startChildWithDelegate_ActiveNotChild() {
        let delegate = TracerDelegate()

        let sut = fixture.getSut()
        sut.delegate = delegate

        delegate.activeSpan = SentryTracer(transactionContext: TransactionContext(name: fixture.transactionName, operation: fixture.transactionOperation), hub: nil)

        let child = sut.startChild(operation: fixture.transactionOperation)

        let secondChild = sut.startChild(operation: fixture.transactionOperation)

        XCTAssertEqual(secondChild.parentSpanId, sut.spanId)
        XCTAssertEqual(secondChild.parentSpanId, child.parentSpanId)
    }

    func test_startChildWithDelegate_SelfIsActive() {
        let delegate = TracerDelegate()

        let sut = fixture.getSut()
        sut.delegate = delegate

        delegate.activeSpan = sut

        let child = sut.startChild(operation: fixture.transactionOperation)

        let secondChild = sut.startChild(operation: fixture.transactionOperation)

        XCTAssertEqual(secondChild.parentSpanId, sut.spanId)
        XCTAssertEqual(secondChild.parentSpanId, child.parentSpanId)
    }

    #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

    func testAddPreWarmedAppStartMeasurement_PutOnNextAutoUITransaction() throws {
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .cold, preWarmed: true)
        SentrySDKInternal.setAppStartMeasurement(appStartMeasurement)

        whenFinishingAutoUITransaction(startTimestamp: 5)

        try assertMeasurements(["app_start_cold": ["value": fixture.appStartDuration * 1_000]])

        let transaction = try XCTUnwrap(fixture.hub.capturedEventsWithScopes.first!.event as? Transaction)
        assertPreWarmedAppStartsSpanAdded(transaction: transaction, startType: "Cold Start", operation: fixture.appStartColdOperation, appStartMeasurement: appStartMeasurement)
    }

    func testAddWarmAppStartMeasurement_PutOnNextAutoUITransaction() throws {
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .warm)
        SentrySDKInternal.setAppStartMeasurement(appStartMeasurement)
        
        advanceTime(bySeconds: -(fixture.appStartDuration + 4))

        let sut = fixture.getSut()
        advanceTime(bySeconds: 1)
        sut.finish()
        
        XCTAssertEqual(1, fixture.hub.capturedEventsWithScopes.count)

        assertAppStartMeasurementOn(transaction: try XCTUnwrap(fixture.hub.capturedEventsWithScopes.first?.event as? Transaction), appStartMeasurement: appStartMeasurement)
    }
    
    func testAddAppStartMeasurementWhileTransactionRunning_PutOnNextAutoUITransaction() throws {
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .warm)
        
        advanceTime(bySeconds: -(fixture.appStartDuration + 4))

        let sut = fixture.getSut()
        advanceTime(bySeconds: 1)
        SentrySDKInternal.setAppStartMeasurement(appStartMeasurement)
        sut.finish()
        
        XCTAssertEqual(self.fixture.hub.capturedEventsWithScopes.count, 1)

        assertAppStartMeasurementOn(transaction: try XCTUnwrap(fixture.hub.capturedEventsWithScopes.first?.event as? Transaction), appStartMeasurement: appStartMeasurement)
    }
    
    func testAddAppStartMeasurement_PutOnFirstFinishedAutoUITransaction() throws {
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .warm)
        SentrySDKInternal.setAppStartMeasurement(appStartMeasurement)

        advanceTime(bySeconds: 0.5)

        let firstTransaction = fixture.getSut()
        advanceTime(bySeconds: 0.5)

        let secondTransaction = fixture.getSut()
        advanceTime(bySeconds: 0.5)
        secondTransaction.finish()

        XCTAssertEqual(self.fixture.hub.capturedEventsWithScopes.count, 1)

        firstTransaction.finish()
        
        XCTAssertEqual(self.fixture.hub.capturedEventsWithScopes.count, 2)
        
        guard fixture.hub.capturedEventsWithScopes.invocations.count > 1 else {
            XCTFail("Not enough events captured")
            return
        }
        
        var events = fixture.hub.capturedEventsWithScopes.invocations
        let firstEvent = events.removeFirst()
        let secondEvent = events.removeFirst()
        
        let serializedFirstTransaction = secondEvent.event.serialize()
        XCTAssertNil(serializedFirstTransaction["measurements"])
        
        assertAppStartMeasurementOn(transaction: try XCTUnwrap(firstEvent.event as? Transaction), appStartMeasurement: appStartMeasurement)
    }
    
    func testAddUnknownAppStartMeasurement_NotPutOnNextTransaction() throws {
        SentrySDKInternal.setAppStartMeasurement(SentryAppStartMeasurement(
            type: SentryAppStartType.unknown,
            isPreWarmed: false,
            appStartTimestamp: fixture.currentDateProvider.date(),
            runtimeInitSystemTimestamp: fixture.currentDateProvider.systemTime(),
            duration: 0.5,
            runtimeInitTimestamp: fixture.currentDateProvider.date(),
            moduleInitializationTimestamp: fixture.currentDateProvider.date(),
            sdkStartTimestamp: fixture.currentDateProvider.date(),
            didFinishLaunchingTimestamp: fixture.currentDateProvider.date()
        ))
        
        fixture.getSut().finish()
        
        try assertAppStartMeasurementNotPutOnTransaction()
    }
    
    func testPreWarmedColdAppStart_AddsStartTypeToContext() throws {
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .cold, preWarmed: true)
        SentrySDKInternal.setAppStartMeasurement(appStartMeasurement)

        whenFinishingAutoUITransaction(startTimestamp: 5)

        try assertAppStartTypeAddedtoContext(expected: "cold.prewarmed")
    }

    func testColdAppStart_AddsStartTypeToContext() throws {
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .cold, preWarmed: false)
        SentrySDKInternal.setAppStartMeasurement(appStartMeasurement)

        whenFinishingAutoUITransaction(startTimestamp: 5)

        try assertAppStartTypeAddedtoContext(expected: "cold")
    }

    func testPreWarmedWarmAppStart_AddsStartTypeToContext() throws {
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .warm, preWarmed: true)
        SentrySDKInternal.setAppStartMeasurement(appStartMeasurement)

        whenFinishingAutoUITransaction(startTimestamp: 5)

        try assertAppStartTypeAddedtoContext(expected: "warm.prewarmed")
    }

    func testPreWarmedWarmAppStart_DoesntAddStartTypeToContext() throws {
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .unknown, preWarmed: true)
        SentrySDKInternal.setAppStartMeasurement(appStartMeasurement)

        whenFinishingAutoUITransaction(startTimestamp: 5)

        try assertAppStartTypeAddedtoContext(expected: nil)
    }

    func testAddWarmAppStartMeasurement_NotPutOnNonAutoUITransaction() throws {
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .warm)
        SentrySDKInternal.setAppStartMeasurement(appStartMeasurement)
        
        let sut = try XCTUnwrap(fixture.hub.startTransaction(transactionContext: TransactionContext(name: "custom", operation: "custom")) as? SentryTracer)
        sut.finish()
        
        XCTAssertNotNil(SentrySDKInternal.getAppStartMeasurement())
        
        XCTAssertEqual(1, fixture.hub.capturedEventsWithScopes.count)
        let serializedTransaction = try XCTUnwrap(fixture.hub.capturedEventsWithScopes.first).event.serialize()
        
        let measurements = serializedTransaction["measurements"] as? [String: [String: Int]]
        
        XCTAssertNil(measurements)
        
        let spans = try XCTUnwrap(serializedTransaction["spans"]! as? [[String: Any]])
        XCTAssertEqual(0, spans.count)
    }
    
    func testAddWarmAppStartMeasurement_TooOldTransaction_NotPutOnTransaction() throws {
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .warm)
        SentrySDKInternal.setAppStartMeasurement(appStartMeasurement)
        
        advanceTime(bySeconds: fixture.appStartDuration + 5.01)

        let sut = fixture.getSut()
        advanceTime(bySeconds: 1.0)
        sut.finish()
        
        try assertAppStartMeasurementNotPutOnTransaction()
    }
    
    func testAddWarmAppStartMeasurement_TooYoungTransaction_NotPutOnTransaction() throws {
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .warm)
        SentrySDKInternal.setAppStartMeasurement(appStartMeasurement)
        
        advanceTime(bySeconds: -(fixture.appStartDuration + 4.01))

        let sut = fixture.getSut()
        advanceTime(bySeconds: 1.0)
        sut.finish()
        
        try assertAppStartMeasurementNotPutOnTransaction()
    }
    
    func testAppStartMeasurementHybridSDKModeEnabled_NotPutOnTransaction() throws {
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .warm)
        SentrySDKInternal.setAppStartMeasurement(appStartMeasurement)
        PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode = true
        
        let sut = fixture.getSut()
        sut.finish()
        
        try assertAppStartMeasurementNotPutOnTransaction()
    }
    
    func testAppStartTransaction_AddsDebugMeta() {
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .cold)
        SentrySDKInternal.setAppStartMeasurement(appStartMeasurement)

        whenFinishingAutoUITransaction(startTimestamp: 5)
        
        XCTAssertEqual(self.fixture.hub.capturedEventsWithScopes.count, 1)
        let serializedTransaction = fixture.hub.capturedEventsWithScopes.first?.event.serialize()
        
        let debugMeta = serializedTransaction?["debug_meta"] as? [String: Any]
        XCTAssertEqual(debugMeta?.count, fixture.debugImageProvider.getDebugImagesFromCache().count)
        
        XCTAssertEqual(2, fixture.debugImageProvider.getDebugImagesFromCacheInvocations.count, "The tracer must retrieve all the debug images from the cache, cause otherwise it can cause app hangs.")
    }
    
    func testNoAppStartTransaction_AddsNoDebugMeta() {
        whenFinishingAutoUITransaction(startTimestamp: 5)
        
        XCTAssertEqual(self.fixture.hub.capturedEventsWithScopes.count, 1)
        let serializedTransaction = fixture.hub.capturedEventsWithScopes.first?.event.serialize()
        
        XCTAssertNil(serializedTransaction?["debug_meta"])
    }

#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    
    func testMeasurementOnChildSpan_SetTwice_OverwritesMeasurement() throws {
        let name = "something"
        let value: NSNumber = -12.34
        let unit = MeasurementUnitFraction.percent

        let sut = fixture.getSut()
        let childSpan = sut.startChild(operation: "operation")
        sut.setMeasurement(name: name, value: 12.0, unit: unit)
        childSpan.setMeasurement(name: name, value: value, unit: unit)
        childSpan.finish()
        sut.finish()

        XCTAssertEqual(1, fixture.hub.capturedEventsWithScopes.count)
        let serializedTransaction = fixture.hub.capturedEventsWithScopes.first?.event.serialize()

        let measurements = try XCTUnwrap(serializedTransaction?["measurements"] as? [String: [String: Any]])
        XCTAssertEqual(1, measurements.count)

        let measurement = try XCTUnwrap(measurements[name])
        XCTAssertEqual(value, try XCTUnwrap(measurement["value"] as? NSNumber))
        XCTAssertEqual(unit.unit, try XCTUnwrap(measurement["unit"] as? String))
    }

    func testMeasurement_NameIsNil_MeasurementsGetsDiscarded() throws {
        // Arrange
        let sut = fixture.getSut()

        // Act
        testing_setMeasurementWithNilName(sut, 0.0)
        testing_setMeasurementWithNilNameAndUnit(sut, 0.0, MeasurementUnitFraction.percent)

        // Assert
        sut.finish()

        XCTAssertEqual(1, fixture.hub.capturedEventsWithScopes.count)
        let serializedTransaction = fixture.hub.capturedEventsWithScopes.first?.event.serialize()

        XCTAssertNil(serializedTransaction?["measurements"])
    }

    func testMeasurements_WriteFromDifferentThreads_SetsAllMeasurements() throws {
        // Arrange
        let iterations = 100
        let unit = MeasurementUnitFraction.percent

        let sut = fixture.getSut()
        let childSpan = sut.startChild(operation: "operation")

        let dispatchQueue = DispatchQueue(label: "testQueue", attributes: .concurrent)
        let expectation = XCTestExpectation(description: "Set measurements")
        expectation.expectedFulfillmentCount = iterations

        // Act
        for i in 0..<iterations {
            dispatchQueue.async {
                sut.setMeasurement(name: "transaction \(i)", value: 12.0, unit: unit)
                childSpan.setMeasurement(name: "span \(i)", value: 10.0, unit: unit)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)

        // Assert
        childSpan.finish()
        sut.finish()
        XCTAssertEqual(1, fixture.hub.capturedEventsWithScopes.count)
        let serializedTransaction = fixture.hub.capturedEventsWithScopes.first?.event.serialize()

        let measurements = try XCTUnwrap(serializedTransaction?["measurements"] as? [String: [String: Any]])
        XCTAssertEqual(measurements.count, iterations * 2)

        for i in 0..<iterations {
            let transactionMeasurement = try XCTUnwrap(measurements["transaction \(i)"])
            XCTAssertEqual(try XCTUnwrap(transactionMeasurement["value"] as? NSNumber), 12.0)

            let spanMeasurement = try XCTUnwrap(measurements["span \(i)"])
            XCTAssertEqual(try XCTUnwrap(spanMeasurement["value"] as? NSNumber), 10.0)
        }
    }

    func testMeasurements_ReadWhileWritingOnDifferentThreads() throws {
        // Arrange
        let iterations = 100
        let unit = MeasurementUnitFraction.percent

        let sut = fixture.getSut()
        let childSpan = sut.startChild(operation: "operation")

        let dispatchQueue = DispatchQueue(label: "testQueue", attributes: .concurrent)
        let expectation = XCTestExpectation(description: "Set measurements")
        expectation.expectedFulfillmentCount = iterations

        // Act && Assert
        for i in 0..<iterations {
            dispatchQueue.async {
                sut.setMeasurement(name: "transaction \(i)", value: 12.0, unit: unit)
                childSpan.setMeasurement(name: "span \(i)", value: 10.0, unit: unit)

                // We only want to ensure we're not crashing here.
                // We don't care about the actual values as we test these in other tests.
                XCTAssertGreaterThanOrEqual(sut.measurements.count, 0)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)
    }

    func testFinish_WithUnfinishedChildren() {
        let sut = fixture.getSut(waitForChildren: false)
        let child1 = sut.startChild(operation: fixture.transactionOperation)
        let child2 = sut.startChild(operation: fixture.transactionOperation)
        let child3 = sut.startChild(operation: fixture.transactionOperation)
        child2.finish()
        
        //Without this sleep sut.timestamp and child2.timestamp sometimes
        //are equal we need to make sure that SentryTracer is not changing
        //the timestamp value of proper finished spans.
        Thread.sleep(forTimeInterval: 0.1)

        fixture.currentDateProvider.setDate(date: SentryDependencyContainer.sharedInstance().dateProvider.date().addingTimeInterval(0.1))
        
        sut.finish()
        
        XCTAssertTrue(child1.isFinished)
        XCTAssertEqual(child1.status, .deadlineExceeded)
        XCTAssertEqual(sut.timestamp, child1.timestamp)
        
        XCTAssertTrue(child2.isFinished)
        XCTAssertEqual(child2.status, .ok)
        XCTAssertNotEqual(sut.timestamp, child2.timestamp)
        
        XCTAssertTrue(child3.isFinished)
        XCTAssertEqual(child3.status, .deadlineExceeded)
        XCTAssertEqual(sut.timestamp, child3.timestamp)
    }
    
    func testFinishCallback_CalledWhenTracerFinishes() {
        let callbackExpectation = expectation(description: "FinishCallback called")
        
        let sut = fixture.getSut(idleTimeout: fixture.idleTimeout)
        
        let block: (SentryTracer) -> Void = { tracer in
            XCTAssertEqual(sut, tracer)
            callbackExpectation.fulfill()
        }
        sut.finishCallback = block
        
        fixture.dispatchQueue.invokeLastDispatchAfter()
        
        XCTAssertNil(sut.finishCallback)
        
        wait(for: [callbackExpectation], timeout: 0.1)
    }
    
    func testFinish_SetScopeSpanToNil() {
        let sut = fixture.getSut()
        fixture.hub.scope.span = sut
        
        sut.finish()
        
        XCTAssertNil(fixture.hub.scope.span)
    }
    
    func testFinish_DifferentSpanOnScope_DoesNotSetScopeSpanToNil() {
        let sut = fixture.getSut()
        let sutOnScope = fixture.getSut()
        fixture.hub.scope.span = sutOnScope
        
        sut.finish()
        
        XCTAssertTrue(sutOnScope === fixture.hub.scope.span)
    }
    
    func testFinishAsync() throws {
        let sut = fixture.getSut()
        let child = sut.startChild(operation: fixture.transactionOperation)
        sut.finish()

        let queue = DispatchQueue(label: "SentryTracerTests", attributes: [.concurrent, .initiallyInactive])
        let group = DispatchGroup()

        let children = 5
        let grandchildren = 10
        for _ in 0 ..< children {
            group.enter()
            queue.async {
                let grandChild = child.startChild(operation: self.fixture.transactionOperation)
                for _ in 0 ..< grandchildren {
                    let grandGrandChild = grandChild.startChild(operation: self.fixture.transactionOperation)
                    grandGrandChild.finish()
                }

                grandChild.finish()
                self.assertTransactionNotCaptured(sut)
                group.leave()
            }
        }

        queue.activate()
        group.wait()

        child.finish()

        assertOneTransactionCaptured(sut)

        let spans = try XCTUnwrap(try getSerializedTransaction()["spans"]! as? [[String: Any]])
        XCTAssertEqual(spans.count, children * (grandchildren + 1) + 1)
    }

    #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

    func testConcurrentTransactions_OnlyOneGetsMeasurement() {
        SentrySDKInternal.setAppStartMeasurement(fixture.getAppStartMeasurement(type: .warm))
        
        let queue = DispatchQueue(label: "", qos: .background, attributes: [.concurrent, .initiallyInactive] )

        let transactions = 5
        let startTransactionExpectation = XCTestExpectation(description: "Start transactions")
        let finishTransactionExpectation = XCTestExpectation(description: "Finish transactions")
        startTransactionExpectation.expectedFulfillmentCount = transactions
        finishTransactionExpectation.expectedFulfillmentCount = transactions

        for _ in 0..<transactions {
            queue.async {
                let tracer = self.fixture.getSut()
                startTransactionExpectation.fulfill()

                tracer.finish()
                finishTransactionExpectation.fulfill()
            }
        }
        
        queue.activate()
        wait(for: [startTransactionExpectation, finishTransactionExpectation], timeout: 5.0)

        XCTAssertEqual(fixture.hub.capturedEventsWithScopes.count, transactions, "Expected \(transactions) transactions to be captured, but got \(fixture.hub.capturedEventsWithScopes.count)")

        let transactionsWithAppStartMeasurement = fixture.hub.capturedEventsWithScopes.invocations.filter { pair in
            let serializedTransaction = pair.event.serialize()
            let measurements = serializedTransaction["measurements"] as? [String: [String: Int]]
            return measurements == ["app_start_warm": ["value": 500]]
        }
        
        XCTAssertEqual(transactionsWithAppStartMeasurement.count, 1, "Only one transaction should have the app start measurement, but got \(transactionsWithAppStartMeasurement.count)")
    }

    #endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    
    func testAddingSpansOnDifferentThread_WhileFinishing_DoesNotCrash() throws {
        let sut = fixture.getSut(waitForChildren: false)

        let children = 1_000
        for _ in 0..<children {
            let child = sut.startChild(operation: self.fixture.transactionOperation)
            child.finish()
        }

        let queue = DispatchQueue(label: "SentryTracerTests", attributes: [.concurrent, .initiallyInactive])
        let group = DispatchGroup()

        func addChildrenAsync() {
            for _ in 0 ..< 100 {
                group.enter()
                queue.async {
                    let child = sut.startChild(operation: self.fixture.transactionOperation)
                    Dynamic(child).frames = [] as [Frame]
                    child.finish()
                    group.leave()
                }
            }
        }

        addChildrenAsync()

        group.enter()
        queue.async {
            sut.finish()
            group.leave()
        }

        addChildrenAsync()

        queue.activate()
        group.wait()

        let spans = try XCTUnwrap(try getSerializedTransaction()["spans"]! as? [[String: Any]])
        XCTAssertGreaterThanOrEqual(spans.count, children)
    }
    
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    
    func testChangeStartTimeStamp_OnlyFramesDelayAdded() throws {
        let sut = fixture.getSut()
        fixture.displayLinkWrapper.renderFrames(0, 0, 100)
        sut.updateStartTime(try XCTUnwrap(sut.startTimestamp).addingTimeInterval(-1))
        
        sut.finish()
        
        XCTAssertEqual(self.fixture.hub.capturedEventsWithScopes.count, 1)
        let serializedTransaction = try XCTUnwrap(fixture.hub.capturedEventsWithScopes.first).event.serialize()
        
        let extra = serializedTransaction["extra"] as? [String: Any]
        
        let framesDelay = try XCTUnwrap(extra?["frames.delay"] as? NSNumber)
        XCTAssertEqual(framesDelay.doubleValue, 0.0, accuracy: 0.0001)
    }
    
    func testAddFramesMeasurement() throws {
        let sut = fixture.getSut()
        
        let displayLink = fixture.displayLinkWrapper
        
        let slowFrames = 1
        let frozenFrames = 1
        let normalFrames = 100
        let totalFrames = slowFrames + frozenFrames + normalFrames
        _ = displayLink.slowestSlowFrame()
        _ = displayLink.fastestFrozenFrame()
        displayLink.renderFrames(0, 0, normalFrames)
        
        sut.finish()
        
        XCTAssertEqual(self.fixture.hub.capturedEventsWithScopes.count, 1)
        let serializedTransaction = try XCTUnwrap(fixture.hub.capturedEventsWithScopes.first).event.serialize()
        let measurements = serializedTransaction["measurements"] as? [String: [String: Any]]
        
        XCTAssertEqual(measurements?["frames_total"] as? [String: Int], ["value": totalFrames])
        XCTAssertEqual(measurements?["frames_slow"] as? [String: Int], ["value": slowFrames])
        XCTAssertEqual(measurements?["frames_frozen"] as? [String: Int], ["value": frozenFrames])
        
        let extra = serializedTransaction["extra"] as? [String: Any]
        let framesDelay = try XCTUnwrap(extra?["frames.delay"] as? NSNumber)
        
        let expectedFrameDuration = slowFrameThreshold(displayLink.currentFrameRate.rawValue)
        let expectedDelay = displayLink.slowestSlowFrameDuration + displayLink.fastestFrozenFrameDuration - expectedFrameDuration * 2 as NSNumber
        
        XCTAssertEqual(framesDelay.doubleValue, expectedDelay.doubleValue, accuracy: 0.0001)
        XCTAssertNil(SentrySDKInternal.getAppStartMeasurement())
    }
    
    func testFramesDelay_WhenBeingZero() throws {
        let sut = fixture.getSut()
        
        let displayLink = fixture.displayLinkWrapper
        let normalFrames = 100
        displayLink.renderFrames(0, 0, normalFrames)
        
        sut.finish()
        
        XCTAssertEqual(self.fixture.hub.capturedEventsWithScopes.count, 1)
        
        let serializedTransaction = try XCTUnwrap(fixture.hub.capturedEventsWithScopes.first).event.serialize()
        let extra = serializedTransaction["extra"] as? [String: Any]
        let framesDelay = try XCTUnwrap(extra?["frames.delay"] as? NSNumber)
        XCTAssertEqual(framesDelay.doubleValue, 0.0, accuracy: 0.0001)
    }
    
    func testNegativeFramesAmount_NoMeasurementAdded() throws {
        fixture.displayLinkWrapper.renderFrames(10, 10, 10)
        
        let sut = fixture.getSut()
        
        SentryDependencyContainer.sharedInstance().framesTracker.resetFrames()
        
        sut.finish()
        
        try assertNoMeasurementsAdded()
    }
#endif
    
    func testFinishShouldBeCalled_Timeout_NotCaptured() throws {
        let sut = fixture.getSut(finishMustBeCalled: true)
        fixture.dispatchQueue.invokeLastDispatchAfter()
        assertTransactionNotCaptured(sut)
    }
    
    @available(*, deprecated)
    func testSetExtra_ForwardsToSetData() {
        let sut = fixture.getSut()
        sut.setExtra(value: 0, key: "key")
        
        let data = sut.data as [String: Any]
        XCTAssertEqual(0, data["key"] as? Int)
    }
    
    func testFinishForCrash_WithWaitForChildren_GetsFinished() {
        let sut = fixture.getSut()
        let child = sut.startChild(operation: "ui.load")
        
        advanceTime(bySeconds: 1.0)
        
        sut.finishForCrash()
        
        let currentTime = fixture.currentDateProvider.date()
        
        XCTAssertTrue(sut.isFinished)
        XCTAssertEqual(currentTime, sut.timestamp)
        
        XCTAssertTrue(child.isFinished)
        XCTAssertEqual(currentTime, child.timestamp)
        XCTAssertEqual(SentrySpanStatus.internalError, child.status)
        
        XCTAssertEqual(SentrySpanStatus.internalError, sut.status)
        
        XCTAssertEqual(1, fixture.client.saveCrashTransactionInvocations.count)
    }
    
    func testFinishForCrash_CallFinishTwice_OnlyOnceSaved() {
        let sut = fixture.getSut()
        _ = sut.startChild(operation: "ui.load")
        
        sut.finishForCrash()
        sut.finishForCrash()
        
        XCTAssertEqual(1, fixture.client.saveCrashTransactionInvocations.count)
    }

    func testFinishForCrash_DoesNotCancelDeadlineTimeout() throws {
        let sut = fixture.getSut()
        _ = sut.startChild(operation: fixture.transactionOperation)
        
        sut.finishForCrash()
        
        XCTAssertEqual(0, fixture.dispatchQueue.dispatchCancelInvocations, "Expected no cancel invocation for the deadline timeout.")
    }

    func testFinishForCrash_DoesNotCallFinishCallback() throws {
        let callbackExpectation = expectation(description: "FinishCallback called")
        callbackExpectation.isInverted = true
        
        let sut = fixture.getSut(idleTimeout: fixture.idleTimeout)
        
        sut.finishCallback = { tracer in
            XCTAssertEqual(sut, tracer)
            callbackExpectation.fulfill()
        }
        
        sut.finishForCrash()
        
        wait(for: [callbackExpectation], timeout: 0.01)
    }
    
    func testFinishForCrash_DoesNotCallTracerDidFinish() throws {
        let delegate = TracerDelegate()

        let sut = fixture.getSut()
        sut.delegate = delegate
        
        sut.finishForCrash()
        
        XCTAssertFalse(delegate.tracerDidFinishCalled)
    }
    
    func testFinishForCrash_DoesNotSetSpanOnScopeToNil() throws {
        
        let sut = fixture.getSut()
        
        fixture.hub.scope.span = sut
        
        sut.finishForCrash()
        
        XCTAssertNotNil(fixture.hub.scope.span)
    }

    private func advanceTime(bySeconds: TimeInterval) {
        fixture.currentDateProvider.setDate(date: fixture.currentDateProvider.date().addingTimeInterval(bySeconds))
    }
    
    private func getSerializedTransaction() throws -> [String: Any] {
         let transaction = try XCTUnwrap( fixture.hub.capturedEventsWithScopes.first?.event)
        
        return transaction.serialize()
    }
    
    private func whenFinishingAutoUITransaction(startTimestamp: TimeInterval) {
        let sut = fixture.getSut()
        sut.updateStartTime(fixture.appStartEnd.addingTimeInterval(startTimestamp))
        sut.finish()
    }

    private func assertTransactionNotCaptured(_ tracer: SentryTracer) {
        XCTAssertEqual(0, fixture.hub.capturedEventsWithScopes.count)
    }
    
    private func assertOneTransactionCaptured(_ tracer: SentryTracer) {
        XCTAssertTrue(tracer.isFinished)
        XCTAssertEqual(1, fixture.hub.capturedEventsWithScopes.count)
    }

    #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    private func assertAppStartsSpanAdded(transaction: Transaction, startType: String, operation: String, appStartMeasurement: SentryAppStartMeasurement) {
        let spans: [SentrySpan]? = Dynamic(transaction).spans
        XCTAssertEqual(spans?.count, 6)
        
        let appLaunchSpan = spans?.first { span in
            span.spanDescription == startType
        }
        let trace: SentryTracer? = Dynamic(transaction).trace
        XCTAssertEqual(operation, appLaunchSpan?.operation)
        XCTAssertEqual("auto.app.start", appLaunchSpan?.origin)
        XCTAssertEqual(trace?.spanId, appLaunchSpan?.parentSpanId)
        XCTAssertEqual(appStartMeasurement.appStartTimestamp, appLaunchSpan?.startTimestamp)
        XCTAssertEqual(fixture.appStartEnd, appLaunchSpan?.timestamp)
        
        func assertSpan(_ description: String, _ startTimestamp: Date, _ timestamp: Date) {
            let span = spans?.first { span in
                span.spanDescription == description
            }
            
            XCTAssertEqual(operation, span?.operation)
            XCTAssertEqual("auto.app.start", span?.origin)
            XCTAssertEqual(appLaunchSpan?.spanId, span?.parentSpanId)
            XCTAssertEqual(startTimestamp, span?.startTimestamp)
            XCTAssertEqual(timestamp, span?.timestamp)
        }
        
        assertSpan("Pre Runtime Init", appStartMeasurement.appStartTimestamp, appStartMeasurement.runtimeInitTimestamp)
        assertSpan("Runtime Init to Pre Main Initializers", appStartMeasurement.runtimeInitTimestamp, appStartMeasurement.moduleInitializationTimestamp)
        assertSpan("UIKit Init", appStartMeasurement.moduleInitializationTimestamp, appStartMeasurement.sdkStartTimestamp)
        assertSpan("Application Init", appStartMeasurement.sdkStartTimestamp, appStartMeasurement.didFinishLaunchingTimestamp)
        assertSpan("Initial Frame Render", appStartMeasurement.didFinishLaunchingTimestamp, fixture.appStartEnd)
    }

    private func assertAppStartMeasurementOn(transaction: Transaction, appStartMeasurement: SentryAppStartMeasurement) {
        let serializedTransaction = transaction.serialize()
        let measurements = serializedTransaction["measurements"] as? [String: [String: Int]]

        let appStartDurationInMillis = Int(fixture.appStartDuration * 1_000)
        XCTAssertEqual(["app_start_warm": ["value": appStartDurationInMillis]], measurements)

        assertAppStartsSpanAdded(transaction: transaction, startType: "Warm Start", operation: fixture.appStartWarmOperation, appStartMeasurement: appStartMeasurement)
    }

    private func assertPreWarmedAppStartsSpanAdded(transaction: Transaction, startType: String, operation: String, appStartMeasurement: SentryAppStartMeasurement) {
            let spans: [SentrySpan]? = Dynamic(transaction).spans
            XCTAssertEqual(spans?.count, 4)

            let appLaunchSpan = spans?.first { span in
                span.spanDescription == startType
            }
            let trace: SentryTracer? = Dynamic(transaction).trace
            XCTAssertEqual(operation, appLaunchSpan?.operation)
            XCTAssertEqual(trace?.spanId, appLaunchSpan?.parentSpanId)
            XCTAssertEqual(appStartMeasurement.appStartTimestamp, appLaunchSpan?.startTimestamp)
            XCTAssertEqual(fixture.appStartEnd.timeIntervalSince1970, appLaunchSpan?.timestamp?.timeIntervalSince1970)

            func assertSpan(_ description: String, _ startTimestamp: Date, _ timestamp: Date) {
                let span = spans?.first { span in
                    span.spanDescription == description
                }

                XCTAssertEqual(operation, span?.operation)
                XCTAssertEqual(appLaunchSpan?.spanId, span?.parentSpanId)
                XCTAssertEqual(startTimestamp, span?.startTimestamp)
                XCTAssertEqual(timestamp, span?.timestamp)
            }

            assertSpan("UIKit Init", appStartMeasurement.moduleInitializationTimestamp, appStartMeasurement.sdkStartTimestamp)
            assertSpan("Application Init", appStartMeasurement.sdkStartTimestamp, appStartMeasurement.didFinishLaunchingTimestamp)
            assertSpan("Initial Frame Render", appStartMeasurement.didFinishLaunchingTimestamp, fixture.appStartEnd)
        }

    private func assertAppStartMeasurementNotPutOnTransaction() throws {
        XCTAssertEqual(1, fixture.hub.capturedEventsWithScopes.count)
        let serializedTransaction = try XCTUnwrap(fixture.hub.capturedEventsWithScopes.first).event.serialize()
        XCTAssertNil(serializedTransaction["measurements"])
        
        let spans = try XCTUnwrap(serializedTransaction["spans"]! as? [[String: Any]])
        XCTAssertEqual(0, spans.count)
    }

#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    
    private func assertNoMeasurementsAdded() throws {
        XCTAssertEqual(1, fixture.hub.capturedEventsWithScopes.count)
        let serializedTransaction = try XCTUnwrap(fixture.hub.capturedEventsWithScopes.first).event.serialize()
        XCTAssertNil(serializedTransaction["measurements"])
    }
    
    private func assertMeasurements(_ expectedMeasurements: [String: [String: Double]]) throws {
        XCTAssertEqual(1, fixture.hub.capturedEventsWithScopes.count)
        let serializedTransaction = try XCTUnwrap(fixture.hub.capturedEventsWithScopes.first).event.serialize()
        let measurements = serializedTransaction["measurements"] as? [String: [String: Double]]

        XCTAssertEqual(expectedMeasurements, measurements)
    }

    private func assertAppStartTypeAddedtoContext(expected: String?) throws {
        XCTAssertEqual(1, fixture.hub.capturedEventsWithScopes.count)
        let serializedTransaction = try XCTUnwrap(fixture.hub.capturedEventsWithScopes.first).event.serialize()
        let context = serializedTransaction["contexts"] as? [String: [String: Any]]

        let appContext = context?["app"] as? [String: String]
        XCTAssertEqual(expected, appContext?["start_type"])
    }

}

class TestSentryApplication: SentryApplication {

    init() {

    }

    func isActive() -> Bool {
        return false
    }

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    var applicationState: UIApplication.State = .active
    var windows: [UIWindow]? = []

    func getDelegate(_ application: UIApplication) -> (any UIApplicationDelegate)? {
        return nil
    }

    func getConnectedScenes(_ application: UIApplication) -> [UIScene] {
        return []
    }

    func relevantViewControllersNames() -> [String]? {
        return ["SentryViewController"]
    }
#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
}

// swiftlint:enable file_length
