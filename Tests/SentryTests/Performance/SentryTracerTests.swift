import XCTest

class SentryTracerTests: XCTestCase {
    
    private class Fixture {
        let client: TestClient
        let hub: TestHub
        let scope: Scope
        
        let transactionName = "Some Transaction"
        let transactionOperation = "ui.load"
        var transactionContext: TransactionContext!
        
        let appStartWarmOperation = "app.start.warm"
        let appStartColdOperation = "app.start.cold"
        
        let currentDateProvider = TestCurrentDateProvider()
        let appStart: Date
        let appStartEnd: Date
        let appStartDuration = 0.5
        
        init() {
            appStart = currentDateProvider.date()
            appStartEnd = appStart.addingTimeInterval(0.5)
            
            transactionContext = TransactionContext(name: transactionName, operation: transactionOperation)
            
            scope = Scope()
            client = TestClient(options: Options())!
            hub = TestHub(client: client, andScope: scope)
            
            CurrentDate.setCurrentDateProvider(currentDateProvider)
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
        assertAppStartsSpanAdded(transaction: transaction, startType: "Cold Start", operation: fixture.appStartColdOperation, appStartMeasurement: appStartMeasurement)
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
        assertAppStartsSpanAdded(transaction: transaction, startType: "Warm Start", operation: fixture.appStartWarmOperation, appStartMeasurement: appStartMeasurement)
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
        
        assertAppStartMeasurementNotPutOnTransaction()
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
        XCTAssertNil(SentrySDK.getAndResetAppStartMeasurement())
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
    
    private func assertAppStartsSpanAdded(transaction: Transaction, startType: String, operation: String, appStartMeasurement: SentryAppStartMeasurement) {
        let spans: [SentrySpan]? = Dynamic(transaction).spans
        XCTAssertEqual(4, spans?.count)
        
        let appLaunchSpan = spans?.first { span in
            span.context.spanDescription == startType
        }
        let trace: SentryTracer? = Dynamic(transaction).trace
        XCTAssertEqual(operation, appLaunchSpan?.context.operation)
        XCTAssertEqual(trace?.context.spanId, appLaunchSpan?.context.parentSpanId)
        XCTAssertEqual(appStartMeasurement.appStartTimestamp, appLaunchSpan?.startTimestamp)
        XCTAssertEqual(fixture.appStartEnd, appLaunchSpan?.timestamp)
        
        let preMainSpan = spans?.first { span in
            span.context.spanDescription == "Pre main"
        }
        XCTAssertEqual(operation, preMainSpan?.context.operation)
        XCTAssertEqual(appLaunchSpan?.context.spanId, preMainSpan?.context.parentSpanId)
        XCTAssertEqual(appStartMeasurement.appStartTimestamp, preMainSpan?.startTimestamp)
        XCTAssertEqual(appStartMeasurement.runtimeInitTimestamp, preMainSpan?.timestamp)
        
        let appInitSpan = spans?.first { span in
            span.context.spanDescription == "UIKit and Application Init"
        }
        XCTAssertEqual(operation, appInitSpan?.context.operation)
        XCTAssertEqual(appLaunchSpan?.context.spanId, appInitSpan?.context.parentSpanId)
        XCTAssertEqual(appStartMeasurement.runtimeInitTimestamp, appInitSpan?.startTimestamp)
        XCTAssertEqual(appStartMeasurement.didFinishLaunchingTimestamp, appInitSpan?.timestamp)
        
        let frameRenderSpan = spans?.first { span in
            span.context.spanDescription == "Initial Frame Render"
        }
        XCTAssertEqual(operation, frameRenderSpan?.context.operation)
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
