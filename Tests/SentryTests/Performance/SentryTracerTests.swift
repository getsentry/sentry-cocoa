import XCTest

class SentryTracerTests: XCTestCase {
    
    private class Fixture {
        let client: TestClient
        let hub: TestHub
        let scope: Scope
        
        let transactionName = "Some Transaction"
        let transactionOperation = "ui.rendering"
        var transactionContext: TransactionContext!
        
        let appStartOperation = "app start"
        
        let currentDateProvider = TestCurrentDateProvider()
        let appStart: Date
        let appStartEnd: Date
        let appStartDuration = 0.5
        
        #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        var displayLinkWrapper: TestDiplayLinkWrapper
        #endif

        init() {
            appStart = currentDateProvider.date()
            appStartEnd = appStart.addingTimeInterval(0.5)
            
            transactionContext = TransactionContext(name: transactionName, operation: transactionOperation)
            
            scope = Scope()
            client = TestClient(options: Options())!
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
            let runtimeInit = appStart.addingTimeInterval(0.2)
            let didFinishLaunching = appStart.addingTimeInterval(0.3)
            
            return SentryAppStartMeasurement(type: type, appStartTimestamp: appStart, duration: appStartDuration, runtimeInitTimestamp: runtimeInit, didFinishLaunchingTimestamp: didFinishLaunching)
        }
        
        func getSut(waitForChildren: Bool = true) -> SentryTracer {
            return SentryTracer(transactionContext: transactionContext, hub: hub, waitForChildren: waitForChildren)
        }
    }
    
    private var fixture: Fixture!
    
    override func setUp() {
        fixture = Fixture()
        SentrySDK.getAndResetAppStartMeasurement()

    }

    override func tearDown() {
        SentrySDK.getAndResetAppStartMeasurement()
        #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
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
        XCTAssertEqual(tracerTimestamp.sentry_toIso8601String(), serialization["timestamp"]! as! String)
        
        for span in spans {
            XCTAssertEqual(tracerTimestamp.sentry_toIso8601String(), span["timestamp"] as! String)
        }
    }
    
    func testFinish_WithoutHub_DoesntCaptureTransaction() {
        let sut = SentryTracer(transactionContext: fixture.transactionContext, hub: nil, waitForChildren: false)
        
        sut.finish()
        
        XCTAssertEqual(0, fixture.hub.capturedEventsWithScopes.count)
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
        XCTAssertNil(SentrySDK.getAndResetAppStartMeasurement())
    
        let transaction = fixture.hub.capturedEventsWithScopes.first!.event as! Transaction
        assertAppStartsSpanAdded(transaction: transaction, startType: "Cold Start", appStartMeasurement: appStartMeasurement)
    }
    
    func testAddWarmAppStartMeasurement_PutOnNextAutoUITransaction() {
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .warm)
        SentrySDK.setAppStartMeasurement(appStartMeasurement)
        
        let sut = fixture.getSut()
        sut.startTimestamp = fixture.appStartEnd.addingTimeInterval(-5)
        sut.finish()
        fixture.hub.group.wait()
        
        XCTAssertEqual(1, fixture.hub.capturedEventsWithScopes.count)
        let serializedTransaction = fixture.hub.capturedEventsWithScopes.first!.event.serialize()
        let measurements = serializedTransaction["measurements"] as? [String: [String: Int]]
        
        XCTAssertEqual(["app_start_warm": ["value": 500]], measurements)
        XCTAssertNil(SentrySDK.getAndResetAppStartMeasurement())
        
        let transaction = fixture.hub.capturedEventsWithScopes.first!.event as! Transaction
        assertAppStartsSpanAdded(transaction: transaction, startType: "Warm Start", appStartMeasurement: appStartMeasurement)
    }
    
    func testAddUnknownAppStartMeasurement_NotPutOnNextTransaction() {
        SentrySDK.setAppStartMeasurement(SentryAppStartMeasurement(
            type: SentryAppStartType.unknown,
            appStartTimestamp: fixture.currentDateProvider.date(),
            duration: 0.5,
            runtimeInitTimestamp: fixture.currentDateProvider.date(),
            didFinishLaunchingTimestamp: fixture.currentDateProvider.date()
        ))
        
        fixture.getSut().finish()
        fixture.hub.group.wait()
        
        XCTAssertNil(SentrySDK.getAndResetAppStartMeasurement())
        
        assertAppStartMeasurementNotPutOnTransaction()
    }
    
    func testAddWarmAppStartMeasurement_NotPutOnNonAutoUITransaction() {
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .warm)
        SentrySDK.setAppStartMeasurement(appStartMeasurement)
        
        let sut = SentryTracer(transactionContext: TransactionContext(name: "custom", operation: "custom"), hub: fixture.hub, waitForChildren: false)
        sut.finish()
        fixture.hub.group.wait()
        
        XCTAssertNotNil(SentrySDK.getAndResetAppStartMeasurement())
        
        XCTAssertEqual(1, fixture.hub.capturedEventsWithScopes.count)
        let serializedTransaction = fixture.hub.capturedEventsWithScopes.first!.event.serialize()
        
        let measurements = serializedTransaction["measurements"] as? [String: [String: Int]]
        XCTAssertEqual(addZeroFrames(measurements: [:]), measurements)
        
        let spans = serializedTransaction["spans"]! as! [[String: Any]]
        XCTAssertEqual(0, spans.count)
    }
    
    func testAddWarmAppStartMeasurement_TooOldTransaction_NotPutOnNonAutoUITransaction() {
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .warm)
        SentrySDK.setAppStartMeasurement(appStartMeasurement)
        
        let sut = fixture.getSut()
        sut.startTimestamp = fixture.appStartEnd.addingTimeInterval(5.1)
        sut.finish()
        fixture.hub.group.wait()
        
        XCTAssertNil(SentrySDK.getAndResetAppStartMeasurement())
        
        assertAppStartMeasurementNotPutOnTransaction()
    }
    
    func testAddWarmAppStartMeasurement_TooYoungTransaction_NotPutOnNonAutoUITransaction() {
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .warm)
        SentrySDK.setAppStartMeasurement(appStartMeasurement)
        
        let sut = fixture.getSut()
        sut.startTimestamp = fixture.appStartEnd.addingTimeInterval(-5.1)
        sut.finish()
        fixture.hub.group.wait()
        
        XCTAssertNil(SentrySDK.getAndResetAppStartMeasurement())
        
        assertAppStartMeasurementNotPutOnTransaction()
    }
    
    // Altough we only run this test above the below specified versions, we exped the
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
    
    // Altough we only run this test above the below specified versions, we exped the
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
        XCTAssertNil(SentrySDK.getAndResetAppStartMeasurement())
    }

    #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

    func testChangeStartTimeStamp_RemovesFramesMeasurement() {
        let sut = fixture.getSut()
        givenFrames(1, 1, 1)
        sut.startTimestamp = Date()

        sut.finish()

        fixture.hub.group.wait()

        XCTAssertEqual(1, fixture.hub.capturedEventsWithScopes.count)
        let serializedTransaction = fixture.hub.capturedEventsWithScopes.first!.event.serialize()
        XCTAssertNil(serializedTransaction["measurements"] as? [String: [String: Int]])
    }

    func testAddFramesMeasurement() {
        let sut = fixture.getSut()

        let slowFrames = 4
        let frozenFrames = 1
        let normalFrames = 100
        let totalFrames = slowFrames + frozenFrames + normalFrames
        givenFrames(slowFrames, frozenFrames, normalFrames)

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
        XCTAssertNil(SentrySDK.getAndResetAppStartMeasurement())
    }

    private func givenFrames(_ slow: Int, _ frozen: Int, _ normal: Int) {
        fixture.displayLinkWrapper.call()

        // Slow frames
        for _ in 0..<slow {
            fixture.displayLinkWrapper.internalTimestamp += TestData.slowFrameThreshold + 0.001
            fixture.displayLinkWrapper.call()
        }

        // Frozen frames
        for _ in 0..<frozen {
            fixture.displayLinkWrapper.internalTimestamp += TestData.frozenFrameThreshold + 0.001
            fixture.displayLinkWrapper.call()
        }

        // Normal frames.
        for _ in 0..<(normal - 1) {
            fixture.displayLinkWrapper.internalTimestamp += TestData.slowFrameThreshold - 0.01
            fixture.displayLinkWrapper.call()
        }
    }
    #endif

    private func addZeroFrames(measurements: [String: [String: Int]]) -> [String: [String: Int]] {
        #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        var noFrames = [
            "frames_total": ["value": 0],
            "frames_slow": ["value": 0],
            "frames_frozen": ["value": 0]
        ]
        #else
        var noFrames: [String: [String: Int]] = [:]
        #endif

        // Merge two dicts
        measurements.forEach { (key, value) in noFrames[key] = value }

        return noFrames
    }
    
    private func getSerializedTransaction() -> [String: Any] {
        guard let transaction = fixture.hub.capturedEventsWithScopes.first?.event else {
            fatalError("Event must not be nil.")
        }
        return transaction.serialize()
    }
    
    private func assertTransactionNotCaptured(_ tracer: SentryTracer) {
        fixture.hub.group.wait()
        XCTAssertFalse(tracer.isFinished)
        XCTAssertEqual(0, fixture.hub.capturedEventsWithScopes.count)
    }
    
    private func assertOneTransactionCaptured(_ tracer: SentryTracer) {
        fixture.hub.group.wait()
        XCTAssertTrue(tracer.isFinished)
        XCTAssertEqual(1, fixture.hub.capturedEventsWithScopes.count)
    }
    
    private func assertAppStartsSpanAdded(transaction: Transaction, startType: String, appStartMeasurement: SentryAppStartMeasurement) {
        let spans: [SentrySpan]? = Dynamic(transaction).spans
        XCTAssertEqual(4, spans?.count)
        
        let appLaunchSpan = spans?.first { span in
            span.context.spanDescription == startType
        }
        let trace: SentryTracer? = Dynamic(transaction).trace
        XCTAssertEqual(fixture.appStartOperation, appLaunchSpan?.context.operation)
        XCTAssertEqual(trace?.context.spanId, appLaunchSpan?.context.parentSpanId)
        XCTAssertEqual(appStartMeasurement.appStartTimestamp, appLaunchSpan?.startTimestamp)
        XCTAssertEqual(fixture.appStartEnd, appLaunchSpan?.timestamp)
        
        let preMainSpan = spans?.first { span in
            span.context.spanDescription == "Pre main"
        }
        XCTAssertEqual(fixture.appStartOperation, preMainSpan?.context.operation)
        XCTAssertEqual(appLaunchSpan?.context.spanId, preMainSpan?.context.parentSpanId)
        XCTAssertEqual(appStartMeasurement.appStartTimestamp, preMainSpan?.startTimestamp)
        XCTAssertEqual(appStartMeasurement.runtimeInitTimestamp, preMainSpan?.timestamp)
        
        let appInitSpan = spans?.first { span in
            span.context.spanDescription == "UIKit and Application Init"
        }
        XCTAssertEqual(fixture.appStartOperation, appInitSpan?.context.operation)
        XCTAssertEqual(appLaunchSpan?.context.spanId, appInitSpan?.context.parentSpanId)
        XCTAssertEqual(appStartMeasurement.runtimeInitTimestamp, appInitSpan?.startTimestamp)
        XCTAssertEqual(appStartMeasurement.didFinishLaunchingTimestamp, appInitSpan?.timestamp)
        
        let frameRenderSpan = spans?.first { span in
            span.context.spanDescription == "Initial Frame Render"
        }
        XCTAssertEqual(fixture.appStartOperation, frameRenderSpan?.context.operation)
        XCTAssertEqual(appLaunchSpan?.context.spanId, frameRenderSpan?.context.parentSpanId)
        XCTAssertEqual(appStartMeasurement.didFinishLaunchingTimestamp, frameRenderSpan?.startTimestamp)
        XCTAssertEqual(fixture.appStartEnd, frameRenderSpan?.timestamp)
    }
    
    private func assertAppStartMeasurementNotPutOnTransaction() {
        XCTAssertEqual(1, fixture.hub.capturedEventsWithScopes.count)
        let serializedTransaction = fixture.hub.capturedEventsWithScopes.first!.event.serialize()
        XCTAssertNil(serializedTransaction["measurements"])
        
        let spans = serializedTransaction["spans"]! as! [[String: Any]]
        XCTAssertEqual(0, spans.count)
    }
}
