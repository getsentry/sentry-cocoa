import XCTest

class SentryTracerTests: XCTestCase {
    
    private class TracerDelegate: SentryTracerDelegate {
        
        var activeSpan: Span?
        
        func activeSpan(for tracer: SentryTracer) -> Span? {
            return activeSpan
        }
    }
    
    private class Fixture {
        let client: TestClient
        let hub: TestHub
        let scope: Scope
        let dispatchQueue = TestSentryDispatchQueueWrapper()
        
        let transactionName = "Some Transaction"
        let transactionOperation = "ui.load"
        var transactionContext: TransactionContext!
        
        let appStartWarmOperation = "app.start.warm"
        let appStartColdOperation = "app.start.cold"
        
        let currentDateProvider = TestCurrentDateProvider()
        let appStart: Date
        let appStartEnd: Date
        let appStartDuration = 0.5
        let testKey = "extra_key"
        let testValue = "extra_value"
        
        let idleTimeout: TimeInterval = 1.0
        
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        var displayLinkWrapper: TestDiplayLinkWrapper
#endif
        
        init() {
            CurrentDate.setCurrentDateProvider(currentDateProvider)
            appStart = currentDateProvider.date()
            appStartEnd = appStart.addingTimeInterval(0.5)
            
            transactionContext = TransactionContext(name: transactionName, operation: transactionOperation)
            
            scope = Scope()
            client = TestClient(options: Options())!
            client.options.tracesSampleRate = 1
            hub = TestHub(client: client, andScope: scope)
            
            CurrentDate.setCurrentDateProvider(currentDateProvider)
            
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
            displayLinkWrapper = TestDiplayLinkWrapper()
            
            SentryFramesTracker.sharedInstance().setDisplayLinkWrapper(displayLinkWrapper)
            SentryFramesTracker.sharedInstance().start()
            displayLinkWrapper.call()
#endif
        }
        
        func getAppStartMeasurement(type: SentryAppStartType) -> SentryAppStartMeasurement {
            let appStartDuration = 0.5
            let main = appStart.addingTimeInterval(0.15)
            let runtimeInit = appStart.addingTimeInterval(0.05)
            let didFinishLaunching = appStart.addingTimeInterval(0.3)
            
            return SentryAppStartMeasurement(type: type, appStartTimestamp: appStart, duration: appStartDuration, runtimeInitTimestamp: runtimeInit, moduleInitializationTimestamp: main, didFinishLaunchingTimestamp: didFinishLaunching)
        }
        
        func getSut(waitForChildren: Bool = true) -> SentryTracer {
            return hub.startTransaction(with: transactionContext, bindToScope: false, waitForChildren: waitForChildren, customSamplingContext: [:]) as! SentryTracer
        }
        
        func getSut(idleTimeout: TimeInterval = 0.0, dispatchQueueWrapper: SentryDispatchQueueWrapper) -> SentryTracer {
            return hub.startTransaction(with: transactionContext, bindToScope: false, customSamplingContext: [:], idleTimeout: idleTimeout, dispatchQueueWrapper: dispatchQueueWrapper)
        }
    }
    
    private var fixture: Fixture!
    
    override func setUp() {
        super.setUp()
        fixture = Fixture()
        SentryTracer.resetAppStartMeasurementRead()
    }
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
        SentryTracer.resetAppStartMeasurementRead()
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        SentryFramesTracker.sharedInstance().resetFrames()
        SentryFramesTracker.sharedInstance().stop()
#endif
    }
    
    func testFinish_WithChildren_WaitsForAllChildren() {
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
        
        let serialization = getSerializedTransaction()
        let spans = serialization["spans"]! as! [[String: Any]]
        
        let tracerTimestamp: NSDate = sut.timestamp! as NSDate
        
        XCTAssertEqual(spans.count, 3)
        XCTAssertEqual(tracerTimestamp.timeIntervalSince1970, serialization["timestamp"] as? TimeInterval)
        
        for span in spans {
            XCTAssertEqual(tracerTimestamp.timeIntervalSince1970, span["timestamp"] as? TimeInterval)
        }
    }
    
    func testFinish_CheckDefaultStatus() {
        let sut = fixture.getSut()
        sut.finish()
        XCTAssertEqual(sut.context.status, .ok)
    }
    
    func testFinish_WithoutHub_DoesntCaptureTransaction() {
        let sut = SentryTracer(transactionContext: fixture.transactionContext, hub: nil, waitForChildren: false)
        
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
    
    func testFinish_WaitForAllChildren_StartTimeModified_NoTransactionCaptured() {
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .cold)
        SentrySDK.setAppStartMeasurement(appStartMeasurement)
        advanceTime(bySeconds: 1)
        
        let sut = fixture.getSut()
        advanceTime(bySeconds: 499)
        
        sut.finish()
        
        assertTransactionNotCaptured(sut)
    }
    
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
    
    func testNonIdleTransaction_CallFinish_DoesNotTrimEndTimestamp() {
        let sut = fixture.getSut()
        
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
        XCTAssertEqual(2, fixture.dispatchQueue.dispatchCancelInvocations.count)
        XCTAssertEqual(1, fixture.dispatchQueue.dispatchAfterInvocations.count)
        
        XCTAssertFalse(sut.isFinished)
        advanceTime(bySeconds: 1)
        child.finish()
        
        XCTAssertEqual(1, fixture.dispatchQueue.dispatchAfterInvocations.count)
        
        XCTAssertTrue(sut.isFinished)
    }
    
    func testAddColdAppStartMeasurement_PutOnNextAutoUITransaction() {
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .cold)
        SentrySDK.setAppStartMeasurement(appStartMeasurement)
        
        let sut = fixture.getSut()
        sut.startTimestamp = fixture.appStartEnd.addingTimeInterval(5)
        sut.finish()
        fixture.hub.group.wait()
        
        XCTAssertEqual(1, fixture.hub.capturedEventsWithScopes.count)
        let serializedTransaction = fixture.hub.capturedEventsWithScopes.first!.event.serialize()
        let measurements = serializedTransaction["measurements"] as? [String: [String: Int]]
        
        XCTAssertEqual(["app_start_cold": ["value": 500]], measurements)
        
        let transaction = fixture.hub.capturedEventsWithScopes.first!.event as! Transaction
        assertAppStartsSpanAdded(transaction: transaction, startType: "Cold Start", operation: fixture.appStartColdOperation, appStartMeasurement: appStartMeasurement)
    }
    
    func test_startChildWithDelegate() {
        let delegate = TracerDelegate()
        
        let sut = fixture.getSut()
        sut.delegate = delegate
        
        let child = sut.startChild(operation: fixture.transactionOperation)
        
        delegate.activeSpan = child
        
        let secondChild = sut.startChild(operation: fixture.transactionOperation)
        
        XCTAssertEqual(secondChild.context.parentSpanId, child.context.spanId)
    }
    
    func test_startChildWithDelegate_ActiveNotChild() {
        let delegate = TracerDelegate()
        
        let sut = fixture.getSut()
        sut.delegate = delegate
        
        delegate.activeSpan = SentryTracer(transactionContext: TransactionContext(name: fixture.transactionName, operation: fixture.transactionOperation), hub: nil)
        
        let child = sut.startChild(operation: fixture.transactionOperation)
        
        let secondChild = sut.startChild(operation: fixture.transactionOperation)
        
        XCTAssertEqual(secondChild.context.parentSpanId, sut.context.spanId)
        XCTAssertEqual(secondChild.context.parentSpanId, child.context.parentSpanId)
    }
    
    func test_startChildWithDelegate_SelfIsActive() {
        let delegate = TracerDelegate()
        
        let sut = fixture.getSut()
        sut.delegate = delegate
        
        delegate.activeSpan = sut
        
        let child = sut.startChild(operation: fixture.transactionOperation)
        
        let secondChild = sut.startChild(operation: fixture.transactionOperation)
        
        XCTAssertEqual(secondChild.context.parentSpanId, sut.context.spanId)
        XCTAssertEqual(secondChild.context.parentSpanId, child.context.parentSpanId)
    }
    
    func testAddWarmAppStartMeasurement_PutOnNextAutoUITransaction() {
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .warm)
        SentrySDK.setAppStartMeasurement(appStartMeasurement)
        
        advanceTime(bySeconds: -(fixture.appStartDuration + 4))
        
        let sut = fixture.getSut()
        advanceTime(bySeconds: 1)
        sut.finish()
        fixture.hub.group.wait()
        
        XCTAssertEqual(1, fixture.hub.capturedEventsWithScopes.count)
        
        assertAppStartMeasurementOn(transaction: fixture.hub.capturedEventsWithScopes.first!.event as! Transaction, appStartMeasurement: appStartMeasurement)
    }
    
    func testAddColdStartMeasurement_PutOnFirstStartedTransaction() {
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .warm)
        SentrySDK.setAppStartMeasurement(appStartMeasurement)
        
        advanceTime(bySeconds: 0.5)
        
        let firstTransaction = fixture.getSut()
        advanceTime(bySeconds: 0.5)
        
        let secondTransaction = fixture.getSut()
        advanceTime(bySeconds: 0.5)
        secondTransaction.finish()
        
        fixture.hub.group.wait()
        XCTAssertEqual(1, fixture.hub.capturedEventsWithScopes.count)
        let serializedSecondTransaction = fixture.hub.capturedEventsWithScopes.first!.event.serialize()
        XCTAssertNil(serializedSecondTransaction["measurements"])
        
        firstTransaction.finish()
        fixture.hub.group.wait()
        
        XCTAssertEqual(2, fixture.hub.capturedEventsWithScopes.count)
        assertAppStartMeasurementOn(transaction: fixture.hub.capturedEventsWithScopes[1].event as! Transaction, appStartMeasurement: appStartMeasurement)
    }
    
    func testAddUnknownAppStartMeasurement_NotPutOnNextTransaction() {
        SentrySDK.setAppStartMeasurement(SentryAppStartMeasurement(
            type: SentryAppStartType.unknown,
            appStartTimestamp: fixture.currentDateProvider.date(),
            duration: 0.5,
            runtimeInitTimestamp: fixture.currentDateProvider.date(),
            moduleInitializationTimestamp: fixture.currentDateProvider.date(),
            didFinishLaunchingTimestamp: fixture.currentDateProvider.date()
        ))
        
        fixture.getSut().finish()
        fixture.hub.group.wait()
        
        assertAppStartMeasurementNotPutOnTransaction()
    }
    
    func testAddWarmAppStartMeasurement_NotPutOnNonAutoUITransaction() {
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .warm)
        SentrySDK.setAppStartMeasurement(appStartMeasurement)
        
        let sut = fixture.hub.startTransaction(transactionContext: TransactionContext(name: "custom", operation: "custom")) as! SentryTracer
        sut.finish()
        fixture.hub.group.wait()
        
        XCTAssertNotNil(SentrySDK.getAppStartMeasurement())
        
        XCTAssertEqual(1, fixture.hub.capturedEventsWithScopes.count)
        let serializedTransaction = fixture.hub.capturedEventsWithScopes.first!.event.serialize()
        
        let measurements = serializedTransaction["measurements"] as? [String: [String: Int]]
        
        XCTAssertNil(measurements)
        
        let spans = serializedTransaction["spans"]! as! [[String: Any]]
        XCTAssertEqual(0, spans.count)
    }
    
    func testAddWarmAppStartMeasurement_TooOldTransaction_NotPutOnNonAutoUITransaction() {
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .warm)
        SentrySDK.setAppStartMeasurement(appStartMeasurement)
        
        advanceTime(bySeconds: fixture.appStartDuration + 5.01)
        
        let sut = fixture.getSut()
        advanceTime(bySeconds: 1.0)
        sut.finish()
        fixture.hub.group.wait()
        
        assertAppStartMeasurementNotPutOnTransaction()
    }
    
    func testAddWarmAppStartMeasurement_TooYoungTransaction_NotPutOnNonAutoUITransaction() {
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .warm)
        SentrySDK.setAppStartMeasurement(appStartMeasurement)
        
        advanceTime(bySeconds: -(fixture.appStartDuration + 4.01))
        
        let sut = fixture.getSut()
        advanceTime(bySeconds: 1.0)
        sut.finish()
        fixture.hub.group.wait()
        
        assertAppStartMeasurementNotPutOnTransaction()
    }
    
    func testAppStartMeasurementHybridSDKModeEnabled_NotPutOnTransaction() {
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .warm)
        SentrySDK.setAppStartMeasurement(appStartMeasurement)
        PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode = true
        
        let sut = fixture.getSut()
        sut.finish()
        fixture.hub.group.wait()
        
        assertAppStartMeasurementNotPutOnTransaction()
    }
    
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
        fixture.hub.group.wait()
        
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
        CurrentDate.setCurrentDateProvider(DefaultCurrentDateProvider.sharedInstance())
        let sut = fixture.getSut(waitForChildren: false)
        let child1 = sut.startChild(operation: fixture.transactionOperation)
        let child2 = sut.startChild(operation: fixture.transactionOperation)
        let child3 = sut.startChild(operation: fixture.transactionOperation)
        child2.finish()
        
        //Without this sleep sut.timestamp and child2.timestamp sometimes
        //are equal we need to make sure that SentryTracer is not changing
        //the timestamp value of proper finished spans.
        Thread.sleep(forTimeInterval: 0.1)
        
        sut.finish()
        
        XCTAssertTrue(child1.isFinished)
        XCTAssertEqual(child1.context.status, .deadlineExceeded)
        XCTAssertEqual(sut.timestamp, child1.timestamp)
        
        XCTAssertTrue(child2.isFinished)
        XCTAssertEqual(child2.context.status, .ok)
        XCTAssertNotEqual(sut.timestamp, child2.timestamp)
        
        XCTAssertTrue(child3.isFinished)
        XCTAssertEqual(child3.context.status, .deadlineExceeded)
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
    
    // Although we only run this test above the below specified versions, we expect the
    // implementation to be thread safe
    @available(tvOS 10.0, *)
    @available(OSX 10.12, *)
    @available(iOS 10.0, *)
    func testFinishAsync() {
        let sut = fixture.getSut()
        let child = sut.startChild(operation: fixture.transactionOperation)
        sut.finish()
        
        let queue = DispatchQueue(label: "SentryTracerTests", attributes: [.concurrent, .initiallyInactive])
        let group = DispatchGroup()
        
        for _ in 0 ..< 5_000 {
            group.enter()
            queue.async {
                let grandChild = child.startChild(operation: self.fixture.transactionOperation)
                for _ in 0 ..< 9 {
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
        
        let spans = getSerializedTransaction()["spans"]! as! [[String: Any]]
        XCTAssertEqual(spans.count, 50_001)
    }
    
    // Although we only run this test above the below specified versions, we expect the
    // implementation to be thread safe
    @available(tvOS 10.0, *)
    @available(OSX 10.12, *)
    @available(iOS 10.0, *)
    func testConcurrentTransactions_OnlyOneGetsMeasurement() {
        SentrySDK.setAppStartMeasurement(fixture.getAppStartMeasurement(type: .warm))
        
        let queue = DispatchQueue(label: "", qos: .background, attributes: [.concurrent, .initiallyInactive] )
        let group = DispatchGroup()
        
        let transactions = 10_000
        for _ in 0..<transactions {
            group.enter()
            queue.async {
                self.fixture.getSut().finish()
                group.leave()
            }
        }
        
        queue.activate()
        group.wait()
        
        fixture.hub.group.wait()
        
        XCTAssertEqual(transactions, fixture.hub.capturedEventsWithScopes.count)
        
        let transactionsWithAppStartMeasrurement = fixture.hub.capturedEventsWithScopes.filter { pair in
            let serializedTransaction = pair.event.serialize()
            let measurements = serializedTransaction["measurements"] as? [String: [String: Int]]
            return measurements == ["app_start_warm": ["value": 500]]
        }
        
        XCTAssertEqual(1, transactionsWithAppStartMeasrurement.count)
    }
    
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    
    func testChangeStartTimeStamp_RemovesFramesMeasurement() {
        let sut = fixture.getSut()
        fixture.displayLinkWrapper.givenFrames(1, 1, 1)
        sut.startTimestamp = sut.startTimestamp?.addingTimeInterval(-1)
        
        sut.finish()
        
        assertNoMeasurementsAdded()
    }
    
    func testAddFramesMeasurement() {
        let sut = fixture.getSut()
        
        let slowFrames = 4
        let frozenFrames = 1
        let normalFrames = 100
        let totalFrames = slowFrames + frozenFrames + normalFrames
        fixture.displayLinkWrapper.givenFrames(slowFrames, frozenFrames, normalFrames)
        
        sut.finish()
        
        fixture.hub.group.wait()
        
        XCTAssertEqual(1, fixture.hub.capturedEventsWithScopes.count)
        let serializedTransaction = fixture.hub.capturedEventsWithScopes.first!.event.serialize()
        let measurements = serializedTransaction["measurements"] as? [String: [String: Int]]
        
        XCTAssertEqual([
            "frames_total": ["value": totalFrames],
            "frames_slow": ["value": slowFrames],
            "frames_frozen": ["value": frozenFrames]
        ], measurements)
        XCTAssertNil(SentrySDK.getAppStartMeasurement())
    }
    
    func testNegativeFramesAmount_NoMeasurementAdded() {
        fixture.displayLinkWrapper.givenFrames(10, 10, 10)
        
        let sut = fixture.getSut()
        
        SentryFramesTracker.sharedInstance().resetFrames()
        
        sut.finish()
        
        assertNoMeasurementsAdded()
    }
#endif
    
    func testSetExtra_ForwardsToSetData() {
        let sut = fixture.getSut()
        sut.setExtra(value: 0, key: "key")
        
        XCTAssertEqual(["key": 0], sut.data as! [String: Int])
    }
    
    func testTagsFromContext_shouldBeSerialized() {
        // given
        fixture.transactionContext.setTag(value: fixture.testValue, key: fixture.testKey)
        let transaction = fixture.getSut()
        
        // when
        let dict = try! XCTUnwrap(transaction.serialize()["tags"] as? [String: String])
        
        // then
        XCTAssertEqual(dict, [fixture.testKey: fixture.testValue])
    }
    
    private func advanceTime(bySeconds: TimeInterval) {
        fixture.currentDateProvider.setDate(date: fixture.currentDateProvider.date().addingTimeInterval(bySeconds))
        
        let delta = bySeconds * Double(NSEC_PER_SEC)
        let newNow = fixture.currentDateProvider.internalDispatchNow + .nanoseconds(Int(delta))
        fixture.currentDateProvider.internalDispatchNow = newNow
    }
    
    private func getSerializedTransaction() -> [String: Any] {
        guard let transaction = fixture.hub.capturedEventsWithScopes.first?.event else {
            fatalError("Event must not be nil.")
        }
        return transaction.serialize()
    }
    
    private func assertTransactionNotCaptured(_ tracer: SentryTracer) {
        fixture.hub.group.wait()
        XCTAssertEqual(0, fixture.hub.capturedEventsWithScopes.count)
    }
    
    private func assertOneTransactionCaptured(_ tracer: SentryTracer) {
        fixture.hub.group.wait()
        XCTAssertTrue(tracer.isFinished)
        XCTAssertEqual(1, fixture.hub.capturedEventsWithScopes.count)
    }
    
    private func assertAppStartsSpanAdded(transaction: Transaction, startType: String, operation: String, appStartMeasurement: SentryAppStartMeasurement) {
        let spans: [SentrySpan]? = Dynamic(transaction).spans
        XCTAssertEqual(5, spans?.count)
        
        let appLaunchSpan = spans?.first { span in
            span.context.spanDescription == startType
        }
        let trace: SentryTracer? = Dynamic(transaction).trace
        XCTAssertEqual(operation, appLaunchSpan?.context.operation)
        XCTAssertEqual(trace?.context.spanId, appLaunchSpan?.context.parentSpanId)
        XCTAssertEqual(appStartMeasurement.appStartTimestamp, appLaunchSpan?.startTimestamp)
        XCTAssertEqual(fixture.appStartEnd, appLaunchSpan?.timestamp)
        
        func assertSpan(_ description: String, _ startTimestamp: Date, _ timestamp: Date) {
            let span = spans?.first { span in
                span.context.spanDescription == description
            }
            
            XCTAssertEqual(operation, span?.context.operation)
            XCTAssertEqual(appLaunchSpan?.context.spanId, span?.context.parentSpanId)
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
        
        XCTAssertEqual(["app_start_warm": ["value": 500]], measurements)
        
        assertAppStartsSpanAdded(transaction: transaction, startType: "Warm Start", operation: fixture.appStartWarmOperation, appStartMeasurement: appStartMeasurement)
    }
    
    private func assertAppStartMeasurementNotPutOnTransaction() {
        XCTAssertEqual(1, fixture.hub.capturedEventsWithScopes.count)
        let serializedTransaction = fixture.hub.capturedEventsWithScopes.first!.event.serialize()
        XCTAssertNil(serializedTransaction["measurements"])
        
        let spans = serializedTransaction["spans"]! as! [[String: Any]]
        XCTAssertEqual(0, spans.count)
    }
    
    private func assertNoMeasurementsAdded() {
        fixture.hub.group.wait()
        
        XCTAssertEqual(1, fixture.hub.capturedEventsWithScopes.count)
        let serializedTransaction = fixture.hub.capturedEventsWithScopes.first?.event.serialize()
        XCTAssertNil(serializedTransaction?["measurements"])
    }
    
}
