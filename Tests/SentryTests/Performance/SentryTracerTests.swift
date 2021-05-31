import XCTest

class SentryTracerTests: XCTestCase {
    
    private class Fixture {
        let client: TestClient
        let hub: TestHub
        let scope: Scope
        
        let transactionName = "Some Transaction"
        let transactionOperation = "Some Operation"
        var transactionContext: TransactionContext!
        
        let currentDateProvider = TestCurrentDateProvider()
        
        init() {
            transactionContext = TransactionContext(name: transactionName, operation: transactionOperation)
            
            scope = Scope()
            client = TestClient(options: Options())!
            hub = TestHub(client: client, andScope: scope)
            
            CurrentDate.setCurrentDateProvider(currentDateProvider)
        }
        
        func getSut(waitForChildren: Bool = true) -> SentryTracer {
            return SentryTracer(transactionContext: transactionContext, hub: hub, waitForChildren: waitForChildren)
        }
    }
    
    private var fixture: Fixture!
    
    override func setUp() {
        
        fixture = Fixture()
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
    
    func testAddColdAppStartMeasurement_GetsPutOnNextTransaction() {
        SentrySDK.appStartMeasurement = SentryAppStartMeasurement(type: SentryAppStartType.cold, appStart: Date(), duration: 0.5, runtimeInit: Date(), didFinishLaunchingTimestamp: Date())
        
        fixture.getSut().finish()
        fixture.hub.group.wait()
        
        XCTAssertEqual(1, fixture.hub.capturedEventsWithScopes.count)
        let serializedTransaction = fixture.hub.capturedEventsWithScopes.first!.event.serialize()
        let measurements = serializedTransaction["measurements"] as? [String: [String: Int]]
        
        XCTAssertEqual(["app_start_cold": ["value": 500]], measurements)
        XCTAssertNil(SentrySDK.appStartMeasurement)
    }
    
    func testAddWarmAppStartMeasurement_GetsPutOnNextTransaction() {
        SentrySDK.appStartMeasurement = SentryAppStartMeasurement(type: SentryAppStartType.warm, appStart: Date(), duration: 0.5, runtimeInit: Date(), didFinishLaunchingTimestamp: Date())
        
        fixture.getSut().finish()
        fixture.hub.group.wait()
        
        XCTAssertEqual(1, fixture.hub.capturedEventsWithScopes.count)
        let serializedTransaction = fixture.hub.capturedEventsWithScopes.first!.event.serialize()
        let measurements = serializedTransaction["measurements"] as? [String: [String: Int]]
        
        XCTAssertEqual(["app_start_warm": ["value": 500]], measurements)
        XCTAssertNil(SentrySDK.appStartMeasurement)
    }
    
    func testAddUnknownAppStartMeasurement_GetsNotPutOnNextTransaction() {
        SentrySDK.appStartMeasurement = SentryAppStartMeasurement(type: SentryAppStartType.unknown, appStart: Date(), duration: 0.5, runtimeInit: Date(), didFinishLaunchingTimestamp: Date())
        
        fixture.getSut().finish()
        fixture.hub.group.wait()
        
        XCTAssertEqual(1, fixture.hub.capturedEventsWithScopes.count)
        let serializedTransaction = fixture.hub.capturedEventsWithScopes.first!.event.serialize()
        XCTAssertNil(serializedTransaction["measurements"])
        
        XCTAssertNil(SentrySDK.appStartMeasurement)
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
                group.leave()
                self.assertTransactionNotCaptured(sut)
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
        SentrySDK.appStartMeasurement = SentryAppStartMeasurement(type: SentryAppStartType.warm, appStart: Date(), duration: 0.5, runtimeInit: Date(), didFinishLaunchingTimestamp: Date())
        
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
        }.count
        
        XCTAssertEqual(1, transactionsWithAppStartMeasrurement)
        XCTAssertNil(SentrySDK.appStartMeasurement)
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
}
