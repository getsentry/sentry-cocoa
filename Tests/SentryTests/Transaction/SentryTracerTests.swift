import XCTest

class SentryTracerTests: XCTestCase {
    
    private class Fixture {
        let hub = TestHub(client: nil, andScope: nil)
        
        let transactionName = "Some Transaction"
        let transactionOperation = "Some Operation"
        
        var sut: SentryTracer {
            let context = TransactionContext(name: transactionName, operation: transactionOperation)
            return SentryTracer(transactionContext: context, hub: hub)
        }
    }
    
    private var fixture: Fixture!
    
    override func setUp() {
        fixture = Fixture()
        SentrySDK.appStartMeasurement = nil
    }
    
    override func tearDown() {
        SentrySDK.appStartMeasurement = nil
    }
    
    func testSpanHierarchy() {
        let tracer = fixture.sut
        let child = tracer.startChild(operation: fixture.transactionOperation)
        let grandChild = child.startChild(operation: fixture.transactionOperation)
        
        let tracerSpans = Dynamic(tracer).spans.asArray!
        let childSpan = Dynamic(child).spans.asArray!
        
        XCTAssertTrue(tracerSpans.contains(child))
        XCTAssertTrue(childSpan.contains(grandChild))
        XCTAssertFalse(tracerSpans.contains(grandChild))
        
        XCTAssertEqual(tracerSpans.count, 1)
        XCTAssertEqual(childSpan.count, 1)
    }
    
    func testSpanFlatList() {
        let tracer = fixture.sut
        let child = tracer.startChild(operation: fixture.transactionOperation)
        let grandChild = child.startChild(operation: fixture.transactionOperation)
        
        let tracerChildren = Dynamic(tracer).children.asArray!
        let childChildren = Dynamic(child).children.asArray!
        
        XCTAssertTrue(tracerChildren.contains(child))
        XCTAssertTrue(tracerChildren.contains(grandChild))
        XCTAssertFalse(childChildren.contains(child))
        
        XCTAssertEqual(tracerChildren.count, 2)
        XCTAssertEqual(childChildren.count, 1)
        
    }

    func testAddColdAppStartMeasurement_GetsPutOnNextTransaction() {
        SentrySDK.appStartMeasurement = SentryAppStartMeasurement(type: SentryAppStartType.cold, appStart: Date(), duration: 0.5, runtimeInit: Date(), didFinishLaunchingTimestamp: Date())
        
        fixture.sut.finish()
        fixture.hub.group.wait()
        
        XCTAssertEqual(1, fixture.hub.capturedEventsWithScopes.count)
        let serializedTransaction = fixture.hub.capturedEventsWithScopes.first!.event.serialize()
        let measurements = serializedTransaction["measurements"] as? [String: [String: Int]]
        
        XCTAssertEqual(["app_start_cold": ["value": 500]], measurements)
        XCTAssertNil(SentrySDK.appStartMeasurement)
    }
    
    func testAddWarmAppStartMeasurement_GetsPutOnNextTransaction() {
        SentrySDK.appStartMeasurement = SentryAppStartMeasurement(type: SentryAppStartType.warm, appStart: Date(), duration: 0.5, runtimeInit: Date(), didFinishLaunchingTimestamp: Date())
        
        fixture.sut.finish()
        fixture.hub.group.wait()
        
        XCTAssertEqual(1, fixture.hub.capturedEventsWithScopes.count)
        let serializedTransaction = fixture.hub.capturedEventsWithScopes.first!.event.serialize()
        let measurements = serializedTransaction["measurements"] as? [String: [String: Int]]
        
        XCTAssertEqual(["app_start_warm": ["value": 500]], measurements)
        XCTAssertNil(SentrySDK.appStartMeasurement)
    }
    
    func testAddUnknownAppStartMeasurement_GetsNotPutOnNextTransaction() {
        SentrySDK.appStartMeasurement = SentryAppStartMeasurement(type: SentryAppStartType.unknown, appStart: Date(), duration: 0.5, runtimeInit: Date(), didFinishLaunchingTimestamp: Date())
        
        fixture.sut.finish()
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
    func testConcurrentTransactions_OnlyOneGetsMeasurement() {
        SentrySDK.appStartMeasurement = SentryAppStartMeasurement(type: SentryAppStartType.warm, appStart: Date(), duration: 0.5, runtimeInit: Date(), didFinishLaunchingTimestamp: Date())
        
        let queue = DispatchQueue(label: "", qos: .background, attributes: [.concurrent, .initiallyInactive] )
        let group = DispatchGroup()
        
        let transactions = 10_000
        for _ in 0..<transactions {
            group.enter()
            queue.async {
                self.fixture.sut.finish()
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
}
