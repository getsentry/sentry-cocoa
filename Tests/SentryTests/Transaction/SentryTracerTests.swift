import Nimble
import SentryTestUtils
import XCTest

// swiftlint:disable file_length
// We are aware that the tracer has a lot of logic and we should maybe
// move some of it to other classes.
class SentryTracerTests: XCTestCase {
    
    private class TracerDelegate: SentryTracerDelegate {

        var activeSpan: Span?

        func activeSpan(for tracer: SentryTracer) -> Span? {
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
        let timerFactory = TestSentryNSTimerFactory()
        
        let transactionName = "Some Transaction"
        let transactionOperation = "ui.load"
        var transactionContext: TransactionContext!
        
        let appStartWarmOperation = "app.start.warm"
        let appStartColdOperation = "app.start.cold"
        
        let currentDateProvider = TestCurrentDateProvider()
        var appStart: Date
        var appStartEnd: Date
        var appStartDuration = 0.5
        let testKey = "extra_key"
        let testValue = "extra_value"
        
        let idleTimeout: TimeInterval = 1.0
        
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        var displayLinkWrapper: TestDisplayLinkWrapper
#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        
        init() {
            dispatchQueue.blockBeforeMainBlock = { false }

            SentryDependencyContainer.sharedInstance().dateProvider = currentDateProvider
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
            let didFinishLaunching = appStart.addingTimeInterval(0.3)
            appStart = preWarmed ? main : appStart
            appStartDuration = preWarmed ? appStartDuration - runtimeInitDuration - mainDuration : appStartDuration

            appStartEnd = appStart.addingTimeInterval(appStartDuration)

            return SentryAppStartMeasurement(type: type, isPreWarmed: preWarmed, appStartTimestamp: appStart, duration: appStartDuration, runtimeInitTimestamp: runtimeInit, moduleInitializationTimestamp: main, didFinishLaunchingTimestamp: didFinishLaunching)
        }
        #endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        
        func getSut(waitForChildren: Bool = true) -> SentryTracer {
            let tracer = hub.startTransaction(
                with: transactionContext,
                bindToScope: false,
                customSamplingContext: [:],
                configuration: SentryTracerConfiguration(block: {
                    $0.waitForChildren = waitForChildren
                    $0.dispatchQueueWrapper = self.dispatchQueue
                    $0.timerFactory = self.timerFactory
                }))
            return tracer
        }
        
        func getSut(idleTimeout: TimeInterval = 0.0, dispatchQueueWrapper: SentryDispatchQueueWrapper) -> SentryTracer {
            let tracer = hub.startTransaction(
                with: transactionContext,
                bindToScope: false,
                customSamplingContext: [:],
                configuration: SentryTracerConfiguration(block: {
                    $0.idleTimeout = idleTimeout
                    $0.dispatchQueueWrapper = dispatchQueueWrapper
                    $0.waitForChildren = true
                })
            )
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
        let spans = serialization["spans"]! as! [[String: Any]]
        
        let tracerTimestamp: NSDate = sut.timestamp! as NSDate
        
        XCTAssertEqual(spans.count, 3)
        XCTAssertEqual(tracerTimestamp.timeIntervalSince1970, serialization["timestamp"] as? TimeInterval)
        
        for span in spans {
            XCTAssertEqual(tracerTimestamp.timeIntervalSince1970, span["timestamp"] as? TimeInterval)
        }
    }

    func testDeadlineTimer_FinishesTransactionAndChildren() {
        fixture.dispatchQueue.blockBeforeMainBlock = { true }
        let sut = fixture.getSut()
        
        let child1 = sut.startChild(operation: fixture.transactionOperation)
        let child2 = sut.startChild(operation: fixture.transactionOperation)
        let child3 = sut.startChild(operation: fixture.transactionOperation)

        child3.finish()

        fixture.timerFactory.fire()

        assertOneTransactionCaptured(sut)

        XCTAssertEqual(sut.status, .deadlineExceeded)
        XCTAssertEqual(child1.status, .deadlineExceeded)
        XCTAssertEqual(child2.status, .deadlineExceeded)
        XCTAssertEqual(child3.status, .ok)
    }
    
    func testDeadlineTimer_StartedAndCancelledOnMainThread() {
        fixture.dispatchQueue.blockBeforeMainBlock = { true }
        
        let sut = fixture.getSut()
        let child1 = sut.startChild(operation: fixture.transactionOperation)

        fixture.timerFactory.fire()
        
        XCTAssertEqual(sut.status, .deadlineExceeded)
        XCTAssertEqual(child1.status, .deadlineExceeded)
        XCTAssertEqual(2, fixture.dispatchQueue.blockOnMainInvocations.count, "The NSTimer must be started and cancelled on the main thread.")
    }
    
    func testCancelDeadlineTimer_TracerDeallocated() throws {
#if !os(tvOS) && !os(watchOS)
        if threadSanitizerIsPresent() {
            throw XCTSkip("doesn't currently work with TSAN enabled. the tracer instance remains retained by something in the TSAN dylib, and we cannot debug the memory graph with TSAN attached to see what is retaining it. it's likely out of our control.")
        }
#endif // !os(tvOS) && !os(watchOS)
        
        var invocations = 0
        fixture.dispatchQueue.blockBeforeMainBlock = {
            // The second invocation the block for invalidating the timer
            // which we want to call manually below.
            if invocations == 1 {
                return false
            }
            
            invocations += 1
            return true
        }
        
        var timer: Timer?
        weak var weakSut: SentryTracer?
        
        // Added internal function so the tracer gets deallocated after executing this function.
        func startTracer() {
            let sut = fixture.getSut()
            
            timer = Dynamic(sut).deadlineTimer.asObject as! Timer?
            weakSut = sut
            
            // The TestHub keeps a reference to the tracer in capturedEventsWithScopes.
            // We set it to nil to avoid that.
            sut.hub = nil
            sut.finish()
        }
        startTracer()
        
        XCTAssertNil(weakSut, "sut was not deallocated")

        fixture.timerFactory.fire()
        
        let invalidateTimerBlock = fixture.dispatchQueue.blockOnMainInvocations.last
        if invalidateTimerBlock != nil {
            invalidateTimerBlock!()
        }
        
        // Ensure the timer was not invalidated
        XCTAssertTrue(timer?.isValid ?? false)
    }
    
    func testDeadlineTimer_WhenCancelling_IsInvalidated() {
        fixture.dispatchQueue.blockBeforeMainBlock = { true }
        
        let sut = fixture.getSut()
        let timer: Timer? = Dynamic(sut).deadlineTimer
        _ = sut.startChild(operation: fixture.transactionOperation)

        fixture.timerFactory.fire()
        
        XCTAssertNil(Dynamic(sut).deadlineTimer.asObject, "DeadlineTimer should be nil.")
        XCTAssertFalse(timer?.isValid ?? true)
    }
    
    func testDeadlineTimer_FiresAfterTracerDeallocated() {
        fixture.dispatchQueue.blockBeforeMainBlock = { true }
        
        // Added internal function so the tracer gets deallocated after executing this function.
        func startTracer() {
            _ = fixture.getSut()
        }
        startTracer()

        fixture.timerFactory.fire()
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
    }

    func testDeadlineTimer_OnlyForAutoTransactions() {
        let sut = fixture.getSut(idleTimeout: fixture.idleTimeout, dispatchQueueWrapper: fixture.dispatchQueue)
        let child1 = sut.startChild(operation: fixture.transactionOperation)
        let child2 = sut.startChild(operation: fixture.transactionOperation)
        let child3 = sut.startChild(operation: fixture.transactionOperation)

        child3.finish()

        fixture.timerFactory.fire()

        XCTAssertEqual(sut.status, .undefined)
        XCTAssertEqual(child1.status, .undefined)
        XCTAssertEqual(child2.status, .undefined)
        XCTAssertEqual(child3.status, .ok)
    }

    func testDeadlineTimer_Finish_Cancels_Timer() {
        let sut = fixture.getSut()
        sut.finish()

        XCTAssertFalse(fixture.timerFactory.overrides.timer.isValid)
    }
    
    func testDeadlineTimer_MultipleSpansFinishedInParallel() {
        let sut = fixture.getSut(idleTimeout: 0.01, dispatchQueueWrapper: SentryDispatchQueueWrapper())
        
        testConcurrentModifications(writeWork: { _ in
            let child = sut.startChild(operation: self.fixture.transactionOperation)
            child.finish()
        })
    }

    func testFinish_CheckDefaultStatus() {
        let sut = fixture.getSut()
        sut.finish()
        fixture.timerFactory.fire()
        XCTAssertEqual(sut.status, .ok)
    }
    
    func testIdleTransactionWithStatus_KeepsStatusWhenAutoFinishing() {
        let status = SentrySpanStatus.aborted
        let sut = fixture.getSut(idleTimeout: fixture.idleTimeout, dispatchQueueWrapper: fixture.dispatchQueue)
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
        
        let sut = fixture.getSut(idleTimeout: fixture.idleTimeout, dispatchQueueWrapper: fixture.dispatchQueue)
        
        assertTransactionNotCaptured(sut)
    }
    
    func testIdleTransaction_CreatingDispatchBlockFailsForFirstChild_FinishesTransaction() {
        let sut = fixture.getSut(idleTimeout: fixture.idleTimeout, dispatchQueueWrapper: fixture.dispatchQueue)
        
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
        SentrySDK.setAppStartMeasurement(appStartMeasurement)
        advanceTime(bySeconds: 1)
        
        let sut = fixture.getSut()
        advanceTime(bySeconds: 499)
        
        sut.finish()
        
        assertTransactionNotCaptured(sut)
    }
    #endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    
    func testFinish_IdleTimeout_ExceedsMaxDuration_NoTransactionCaptured() {
        let sut = fixture.getSut(idleTimeout: fixture.idleTimeout, dispatchQueueWrapper: fixture.dispatchQueue)
        
        advanceTime(bySeconds: 500)
        
        sut.finish()
        
        assertTransactionNotCaptured(sut)
    }
    
    func testIdleTimeout_NoChildren_TransactionNotCaptured() {
        _ = fixture.getSut(idleTimeout: fixture.idleTimeout, dispatchQueueWrapper: fixture.dispatchQueue)
        
        fixture.dispatchQueue.invokeLastDispatchAfter()
        
        XCTAssertEqual(0, fixture.hub.capturedEventsWithScopes.count)
    }
    
    func testIdleTimeout_NoChildren_SpanOnScopeUnset() {
        let sut = fixture.getSut(idleTimeout: fixture.idleTimeout, dispatchQueueWrapper: fixture.dispatchQueue)
        
        fixture.hub.scope.span = sut
        
        fixture.dispatchQueue.invokeLastDispatchAfter()
        
        XCTAssertNil(fixture.hub.scope.span)
    }
    
    func testIdleTimeout_InvokesDispatchAfterWithCorrectWhen() {
        _ = fixture.getSut(idleTimeout: fixture.idleTimeout, dispatchQueueWrapper: fixture.dispatchQueue)
        
        fixture.dispatchQueue.invokeLastDispatchAfter()
        
        XCTAssertEqual(fixture.idleTimeout, fixture.dispatchQueue.dispatchAfterInvocations.invocations.first?.interval)
    }
    
    func testIdleTimeout_SpanAdded_IdleTimeoutCancelled() {
        let sut = fixture.getSut(idleTimeout: fixture.idleTimeout, dispatchQueueWrapper: fixture.dispatchQueue)
        
        sut.startChild(operation: fixture.transactionOperation)
        
        XCTAssertEqual(1, fixture.dispatchQueue.dispatchAfterInvocations.count)
        XCTAssertEqual(1, fixture.dispatchQueue.dispatchCancelInvocations.count)
    }
    
    func testIdleTimeoutWithRealDispatchQueue_SpanAdded_IdleTimeoutCancelled() {
        let sut = fixture.getSut(idleTimeout: 0.1, dispatchQueueWrapper: SentryDispatchQueueWrapper())
        
        let child = sut.startChild(operation: fixture.transactionOperation)
        let grandChild = child.startChild(operation: fixture.transactionOperation)
        grandChild.finish()
        child.finish()
        
        delayNonBlocking(timeout: 0.5)
        
        assertOneTransactionCaptured(sut)
    }
    
    func testIdleTimeout_TwoChildren_FirstFinishes_WaitsForTheOther() {
        let sut = fixture.getSut(idleTimeout: fixture.idleTimeout, dispatchQueueWrapper: fixture.dispatchQueue)
        
        let child1 = sut.startChild(operation: fixture.transactionOperation)
        let child2 = sut.startChild(operation: fixture.transactionOperation)
        
        XCTAssertEqual(1, fixture.dispatchQueue.dispatchAfterInvocations.count)
        child1.finish()
        XCTAssertEqual(1, fixture.dispatchQueue.dispatchAfterInvocations.count)
        
        child2.finish()
        XCTAssertEqual(2, fixture.dispatchQueue.dispatchAfterInvocations.count)
        
        fixture.dispatchQueue.invokeLastDispatchAfter()
        
        assertOneTransactionCaptured(sut)
    }
    
    func testIdleTimeout_ChildSpanFinished_IdleStarted() {
        let sut = fixture.getSut(idleTimeout: fixture.idleTimeout, dispatchQueueWrapper: fixture.dispatchQueue)
        XCTAssertEqual(1, fixture.dispatchQueue.dispatchAfterInvocations.count)
        
        let child = sut.startChild(operation: fixture.transactionOperation)
        XCTAssertEqual(1, fixture.dispatchQueue.dispatchCancelInvocations.count)
        
        child.finish()
        XCTAssertEqual(2, fixture.dispatchQueue.dispatchAfterInvocations.count)

        // The grandchild is a NoOp span
        let grandChild = child.startChild(operation: fixture.transactionOperation)
        XCTAssertEqual(3, fixture.dispatchQueue.dispatchCancelInvocations.count)
        
        grandChild.finish()
        XCTAssertEqual(3, fixture.dispatchQueue.dispatchAfterInvocations.count)
        XCTAssertEqual(4, fixture.dispatchQueue.dispatchCancelInvocations.count)
        
        fixture.dispatchQueue.invokeLastDispatchAfter()
        
        assertOneTransactionCaptured(sut)
    }
    
    func testIdleTimeout_TimesOut_TrimsEndTimestamp() {
        let sut = fixture.getSut(idleTimeout: fixture.idleTimeout, dispatchQueueWrapper: fixture.dispatchQueue)
        
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
        let sut = fixture.getSut(idleTimeout: fixture.idleTimeout, dispatchQueueWrapper: fixture.dispatchQueue)
        
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
        if threadSanitizerIsPresent() {
            throw XCTSkip("doesn't currently work with TSAN enabled. the tracer instance remains retained by something in the TSAN dylib, and we cannot debug the memory graph with TSAN attached to see what is retaining it. it's likely out of our control.")
        }
#endif // !os(tvOS) && !os(watchOS)
        
        // Interact with sut in extra function so ARC deallocates it
        func getSut() {
            let sut = fixture.getSut(idleTimeout: fixture.idleTimeout, dispatchQueueWrapper: fixture.dispatchQueue)
            
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
        let sut = fixture.getSut(idleTimeout: fixture.idleTimeout, dispatchQueueWrapper: fixture.dispatchQueue)
        
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
        let sut = fixture.getSut(idleTimeout: fixture.idleTimeout, dispatchQueueWrapper: fixture.dispatchQueue)
        
        let child = sut.startChild(operation: fixture.transactionOperation)
        XCTAssertEqual(1, fixture.dispatchQueue.dispatchAfterInvocations.count)
        
        sut.finish()
        XCTAssertEqual(1, fixture.dispatchQueue.dispatchCancelInvocations.count)
        XCTAssertEqual(1, fixture.dispatchQueue.dispatchAfterInvocations.count)
        
        XCTAssertFalse(sut.isFinished)
        advanceTime(bySeconds: 1)
        child.finish()
        
        XCTAssertEqual(1, fixture.dispatchQueue.dispatchAfterInvocations.count)
        
        XCTAssertTrue(sut.isFinished)
    }

    #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    func testAddColdAppStartMeasurement_PutOnNextAutoUITransaction() {
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .cold)
        SentrySDK.setAppStartMeasurement(appStartMeasurement)
        
        whenFinishingAutoUITransaction(startTimestamp: 5)

        assertMeasurements(["app_start_cold": ["value": fixture.appStartDuration * 1_000]])

        let transaction = fixture.hub.capturedEventsWithScopes.first!.event as! Transaction
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

    func testAddPreWarmedAppStartMeasurement_PutOnNextAutoUITransaction() {
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .cold, preWarmed: true)
        SentrySDK.setAppStartMeasurement(appStartMeasurement)

        whenFinishingAutoUITransaction(startTimestamp: 5)

        assertMeasurements(["app_start_cold": ["value": fixture.appStartDuration * 1_000]])

        let transaction = fixture.hub.capturedEventsWithScopes.first!.event as! Transaction
        assertPreWarmedAppStartsSpanAdded(transaction: transaction, startType: "Cold Start", operation: fixture.appStartColdOperation, appStartMeasurement: appStartMeasurement)
    }

    func testAddWarmAppStartMeasurement_PutOnNextAutoUITransaction() {
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .warm)
        SentrySDK.setAppStartMeasurement(appStartMeasurement)
        
        advanceTime(bySeconds: -(fixture.appStartDuration + 4))

        let sut = fixture.getSut()
        advanceTime(bySeconds: 1)
        sut.finish()
        
        XCTAssertEqual(1, fixture.hub.capturedEventsWithScopes.count)

        assertAppStartMeasurementOn(transaction: fixture.hub.capturedEventsWithScopes.first!.event as! Transaction, appStartMeasurement: appStartMeasurement)
    }
    
    func testAddAppStartMeasurementWhileTransactionRunning_PutOnNextAutoUITransaction() {
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .warm)
        
        advanceTime(bySeconds: -(fixture.appStartDuration + 4))

        let sut = fixture.getSut()
        advanceTime(bySeconds: 1)
        SentrySDK.setAppStartMeasurement(appStartMeasurement)
        sut.finish()
        
        expect(self.fixture.hub.capturedEventsWithScopes.count) == 1

        assertAppStartMeasurementOn(transaction: fixture.hub.capturedEventsWithScopes.first!.event as! Transaction, appStartMeasurement: appStartMeasurement)
    }
    
    func testAddAppStartMeasurement_PutOnFirstFinishedAutoUITransaction() {
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .warm)
        SentrySDK.setAppStartMeasurement(appStartMeasurement)

        advanceTime(bySeconds: 0.5)

        let firstTransaction = fixture.getSut()
        advanceTime(bySeconds: 0.5)

        let secondTransaction = fixture.getSut()
        advanceTime(bySeconds: 0.5)
        secondTransaction.finish()

        expect(self.fixture.hub.capturedEventsWithScopes.count) == 1

        firstTransaction.finish()
        
        expect(self.fixture.hub.capturedEventsWithScopes.count) == 2
        
        let serializedFirstTransaction = fixture.hub.capturedEventsWithScopes.invocations[1].event.serialize()
        expect(serializedFirstTransaction["measurements"]) == nil
        
        assertAppStartMeasurementOn(transaction: fixture.hub.capturedEventsWithScopes.invocations[0].event as! Transaction, appStartMeasurement: appStartMeasurement)
    }
    
    func testAddUnknownAppStartMeasurement_NotPutOnNextTransaction() {
        SentrySDK.setAppStartMeasurement(SentryAppStartMeasurement(
            type: SentryAppStartType.unknown,
            isPreWarmed: false,
            appStartTimestamp: fixture.currentDateProvider.date(),
            duration: 0.5,
            runtimeInitTimestamp: fixture.currentDateProvider.date(),
            moduleInitializationTimestamp: fixture.currentDateProvider.date(),
            didFinishLaunchingTimestamp: fixture.currentDateProvider.date()
        ))
        
        fixture.getSut().finish()
        
        assertAppStartMeasurementNotPutOnTransaction()
    }
    
    func testPreWarmedColdAppStart_AddsStartTypeToContext() {
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .cold, preWarmed: true)
        SentrySDK.setAppStartMeasurement(appStartMeasurement)

        whenFinishingAutoUITransaction(startTimestamp: 5)

        assertAppStartTypeAddedtoContext(expected: "cold.prewarmed")
    }

    func testColdAppStart_AddsStartTypeToContext() {
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .cold, preWarmed: false)
        SentrySDK.setAppStartMeasurement(appStartMeasurement)

        whenFinishingAutoUITransaction(startTimestamp: 5)

        assertAppStartTypeAddedtoContext(expected: "cold")
    }

    func testPreWarmedWarmAppStart_AddsStartTypeToContext() {
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .warm, preWarmed: true)
        SentrySDK.setAppStartMeasurement(appStartMeasurement)

        whenFinishingAutoUITransaction(startTimestamp: 5)

        assertAppStartTypeAddedtoContext(expected: "warm.prewarmed")
    }

    func testPreWarmedWarmAppStart_DoesntAddStartTypeToContext() {
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .unknown, preWarmed: true)
        SentrySDK.setAppStartMeasurement(appStartMeasurement)

        whenFinishingAutoUITransaction(startTimestamp: 5)

        assertAppStartTypeAddedtoContext(expected: nil)
    }

    func testAddWarmAppStartMeasurement_NotPutOnNonAutoUITransaction() {
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .warm)
        SentrySDK.setAppStartMeasurement(appStartMeasurement)
        
        let sut = fixture.hub.startTransaction(transactionContext: TransactionContext(name: "custom", operation: "custom")) as! SentryTracer
        sut.finish()
        
        XCTAssertNotNil(SentrySDK.getAppStartMeasurement())
        
        XCTAssertEqual(1, fixture.hub.capturedEventsWithScopes.count)
        let serializedTransaction = fixture.hub.capturedEventsWithScopes.first!.event.serialize()
        
        let measurements = serializedTransaction["measurements"] as? [String: [String: Int]]
        
        XCTAssertNil(measurements)
        
        let spans = serializedTransaction["spans"]! as! [[String: Any]]
        XCTAssertEqual(0, spans.count)
    }
    
    func testAddWarmAppStartMeasurement_TooOldTransaction_NotPutOnTransaction() {
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .warm)
        SentrySDK.setAppStartMeasurement(appStartMeasurement)
        
        advanceTime(bySeconds: fixture.appStartDuration + 5.01)

        let sut = fixture.getSut()
        advanceTime(bySeconds: 1.0)
        sut.finish()
        
        assertAppStartMeasurementNotPutOnTransaction()
    }
    
    func testAddWarmAppStartMeasurement_TooYoungTransaction_NotPutOnTransaction() {
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .warm)
        SentrySDK.setAppStartMeasurement(appStartMeasurement)
        
        advanceTime(bySeconds: -(fixture.appStartDuration + 4.01))

        let sut = fixture.getSut()
        advanceTime(bySeconds: 1.0)
        sut.finish()
        
        assertAppStartMeasurementNotPutOnTransaction()
    }
    
    func testAppStartMeasurementHybridSDKModeEnabled_NotPutOnTransaction() {
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .warm)
        SentrySDK.setAppStartMeasurement(appStartMeasurement)
        PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode = true
        
        let sut = fixture.getSut()
        sut.finish()
        
        assertAppStartMeasurementNotPutOnTransaction()
    }

#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    
    func testMeasurementOnChildSpan_SetTwice_OverwritesMeasurement() {
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

        let measurements = serializedTransaction?["measurements"] as? [String: [String: Any]]
        XCTAssertEqual(1, measurements?.count)

        let measurement = measurements?[name]
        XCTAssertNotNil(measurement)
        XCTAssertEqual(value, measurement?["value"] as! NSNumber)
        XCTAssertEqual(unit.unit, measurement?["unit"] as! String)
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
        
        let sut = fixture.getSut(idleTimeout: fixture.idleTimeout, dispatchQueueWrapper: fixture.dispatchQueue)
        
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
        
        let spans = try getSerializedTransaction()["spans"]! as! [[String: Any]]
        XCTAssertEqual(spans.count, children * (grandchildren + 1) + 1)
    }

    #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

    func testConcurrentTransactions_OnlyOneGetsMeasurement() {
        SentrySDK.setAppStartMeasurement(fixture.getAppStartMeasurement(type: .warm))
        
        let queue = DispatchQueue(label: "", qos: .background, attributes: [.concurrent, .initiallyInactive] )
        let group = DispatchGroup()
        
        let transactions = 5
        for _ in 0..<transactions {
            group.enter()
            queue.async {
                self.fixture.getSut().finish()
                group.leave()
            }
        }
        
        queue.activate()
        group.wait()
        
        XCTAssertEqual(transactions, fixture.hub.capturedEventsWithScopes.count)
        
        let transactionsWithAppStartMeasurement = fixture.hub.capturedEventsWithScopes.invocations.filter { pair in
            let serializedTransaction = pair.event.serialize()
            let measurements = serializedTransaction["measurements"] as? [String: [String: Int]]
            return measurements == ["app_start_warm": ["value": 500]]
        }
        
        XCTAssertEqual(1, transactionsWithAppStartMeasurement.count)
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
        
        let spans = try getSerializedTransaction()["spans"]! as! [[String: Any]]
        XCTAssertGreaterThanOrEqual(spans.count, children)
    }
    
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    
    func testChangeStartTimeStamp_OnlyFramesDelayAdded() throws {
        let sut = fixture.getSut()
        fixture.displayLinkWrapper.renderFrames(0, 0, 100)
        sut.updateStartTime(try XCTUnwrap(sut.startTimestamp).addingTimeInterval(-1))
        
        sut.finish()
        
        expect(self.fixture.hub.capturedEventsWithScopes.count) == 1
        let serializedTransaction = fixture.hub.capturedEventsWithScopes.first!.event.serialize()
        
        let extra = serializedTransaction["extra"] as? [String: Any]
        
        let framesDelay = extra?["frames.delay"] as? NSNumber
        expect(framesDelay).to(beCloseTo(0.0, within: 0.0001))
    }
    
    func testAddFramesMeasurement() {
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
        
        expect(self.fixture.hub.capturedEventsWithScopes.count) == 1
        let serializedTransaction = fixture.hub.capturedEventsWithScopes.first!.event.serialize()
        let measurements = serializedTransaction["measurements"] as? [String: [String: Any]]
        
        expect(measurements?["frames_total"] as? [String: Int]) == ["value": totalFrames]
        expect(measurements?["frames_slow"] as? [String: Int]) == ["value": slowFrames]
        expect(measurements?["frames_frozen"] as? [String: Int]) == ["value": frozenFrames]
        
        let extra = serializedTransaction["extra"] as? [String: Any]
        let framesDelay = extra?["frames.delay"] as? NSNumber
        
        let expectedFrameDuration = slowFrameThreshold(displayLink.currentFrameRate.rawValue)
        let expectedDelay = displayLink.slowestSlowFrameDuration + displayLink.fastestFrozenFrameDuration - expectedFrameDuration * 2 as NSNumber
        
        expect(framesDelay).to(beCloseTo(expectedDelay, within: 0.0001))
        expect(SentrySDK.getAppStartMeasurement()) == nil
    }
    
    func testFramesDelay_WhenBeingZero() {
        let sut = fixture.getSut()
        
        let displayLink = fixture.displayLinkWrapper
        let normalFrames = 100
        displayLink.renderFrames(0, 0, normalFrames)
        
        sut.finish()
        
        expect(self.fixture.hub.capturedEventsWithScopes.count) == 1
        
        let serializedTransaction = fixture.hub.capturedEventsWithScopes.first!.event.serialize()
        let extra = serializedTransaction["extra"] as? [String: Any]
        let framesDelay = extra?["frames.delay"] as? NSNumber
        expect(framesDelay).to(beCloseTo(0.0, within: 0.0001))
    }
    
    func testNegativeFramesAmount_NoMeasurementAdded() {
        fixture.displayLinkWrapper.renderFrames(10, 10, 10)
        
        let sut = fixture.getSut()
        
        SentryDependencyContainer.sharedInstance().framesTracker.resetFrames()
        
        sut.finish()
        
        assertNoMeasurementsAdded()
    }
#endif
    
    @available(*, deprecated)
    func testSetExtra_ForwardsToSetData() {
        let sut = fixture.getSut()
        sut.setExtra(value: 0, key: "key")
        
        let data = sut.data as [String: Any]
        XCTAssertEqual(0, data["key"] as? Int)
    }

    private func advanceTime(bySeconds: TimeInterval) {
        fixture.currentDateProvider.setDate(date: fixture.currentDateProvider.date().addingTimeInterval(bySeconds))
        
        let delta = bySeconds * Double(NSEC_PER_SEC)
        let newNow = fixture.currentDateProvider.internalDispatchNow + .nanoseconds(Int(delta))
        fixture.currentDateProvider.internalDispatchNow = newNow
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
        XCTAssertEqual(5, spans?.count)
        
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
        assertSpan("UIKit and Application Init", appStartMeasurement.moduleInitializationTimestamp, appStartMeasurement.didFinishLaunchingTimestamp)
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
            XCTAssertEqual(3, spans?.count)

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

            assertSpan("UIKit and Application Init", appStartMeasurement.moduleInitializationTimestamp, appStartMeasurement.didFinishLaunchingTimestamp)
            assertSpan("Initial Frame Render", appStartMeasurement.didFinishLaunchingTimestamp, fixture.appStartEnd)
        }

    private func assertAppStartMeasurementNotPutOnTransaction() {
        XCTAssertEqual(1, fixture.hub.capturedEventsWithScopes.count)
        let serializedTransaction = fixture.hub.capturedEventsWithScopes.first!.event.serialize()
        XCTAssertNil(serializedTransaction["measurements"])
        
        let spans = serializedTransaction["spans"]! as! [[String: Any]]
        XCTAssertEqual(0, spans.count)
    }

#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    
    private func assertNoMeasurementsAdded() {
        XCTAssertEqual(1, fixture.hub.capturedEventsWithScopes.count)
        let serializedTransaction = fixture.hub.capturedEventsWithScopes.first?.event.serialize()
        XCTAssertNil(serializedTransaction?["measurements"])
    }
    
    private func assertMeasurements(_ expectedMeasurements: [String: [String: Double]]) {
        XCTAssertEqual(1, fixture.hub.capturedEventsWithScopes.count)
        let serializedTransaction = fixture.hub.capturedEventsWithScopes.first!.event.serialize()
        let measurements = serializedTransaction["measurements"] as? [String: [String: Double]]

        XCTAssertEqual(expectedMeasurements, measurements)
    }

    private func assertAppStartTypeAddedtoContext(expected: String?) {
        XCTAssertEqual(1, fixture.hub.capturedEventsWithScopes.count)
        let serializedTransaction = fixture.hub.capturedEventsWithScopes.first!.event.serialize()
        let context = serializedTransaction["contexts"] as? [String: [String: Any]]

        let appContext = context?["app"] as? [String: String]
        XCTAssertEqual(expected, appContext?["start_type"])
    }

}

// swiftlint:enable file_length
