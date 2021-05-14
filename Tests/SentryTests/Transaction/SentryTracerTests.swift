import XCTest

class SentryTracerTests: XCTestCase {
    
    private class Fixture {
        let hub = TestHub(client: nil, andScope: nil)
        
        var sut: SentryTracer {
            let context = TransactionContext(name: "name", operation: "operation")
            return SentryTracer(transactionContext: context, hub: hub)
        }
    }
    
    private var fixture: Fixture!
    
    override func setUp() {
        fixture = Fixture()
    }

    func testAddColdAppStartMeasurement_GetsPutOnNextTransaction() {
        SentrySDK.appStartMeasurement = SentryAppStartMeasurement(type: "cold", duration: 0.5)
        
        fixture.sut.finish()
        
        XCTAssertEqual(1, fixture.hub.capturedEventsWithScopes.count)
        let serializedTransaction = fixture.hub.capturedEventsWithScopes.first!.event.serialize()
        let measurements = serializedTransaction["measurements"] as? [String: [String: Double]]
        
        XCTAssertEqual(["app_start_time_cold": ["value": 500.0]], measurements)
        XCTAssertNil(SentrySDK.appStartMeasurement)
    }
    
    func testAddWarmAppStartMeasurement_GetsPutOnNextTransaction() {
        SentrySDK.appStartMeasurement = SentryAppStartMeasurement(type: "warm", duration: 0.5)
        
        fixture.sut.finish()
        
        XCTAssertEqual(1, fixture.hub.capturedEventsWithScopes.count)
        let serializedTransaction = fixture.hub.capturedEventsWithScopes.first!.event.serialize()
        let measurements = serializedTransaction["measurements"] as? [String: [String: Double]]
        
        XCTAssertEqual(["app_start_time_warm": ["value": 500.0]], measurements)
        XCTAssertNil(SentrySDK.appStartMeasurement)
    }
    
    func testAddGarbageAppStartMeasurement_GetsNotPutOnNextTransaction() {
        SentrySDK.appStartMeasurement = SentryAppStartMeasurement(type: "b", duration: 0.5)
        
        fixture.sut.finish()
        
        XCTAssertEqual(1, fixture.hub.capturedEventsWithScopes.count)
        let serializedTransaction = fixture.hub.capturedEventsWithScopes.first!.event.serialize()
        XCTAssertNil(serializedTransaction["measurements"])
        
        XCTAssertNil(SentrySDK.appStartMeasurement)
    }
}
