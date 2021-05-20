import XCTest

class SentryTracerTests: XCTestCase {
    
    private class Fixture {
        let hub = TestHub(client: nil, andScope: nil)
        var displayLinkWrapper: TestDiplayLinkWrapper
        
        init() {
            displayLinkWrapper = TestDiplayLinkWrapper()
            
            SentryFramesTracker.sharedInstance().setDisplayLinkWrapper(displayLinkWrapper)
        }
        
        var sut: SentryTracer {
            let context = TransactionContext(name: "name", operation: "operation")
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
        SentryFramesTracker.sharedInstance().stop()
    }

    func testAddColdAppStartMeasurement_GetsPutOnNextTransaction() {
        SentrySDK.appStartMeasurement = SentryAppStartMeasurement(type: "cold", duration: 0.5)
        
        fixture.sut.finish()
        fixture.hub.group.wait()
        
        XCTAssertEqual(1, fixture.hub.capturedEventsWithScopes.count)
        let serializedTransaction = fixture.hub.capturedEventsWithScopes.first!.event.serialize()
        let measurements = serializedTransaction["measurements"] as? [String: [String: Int]]
        
        XCTAssertEqual(["app_start_cold": ["value": 500]], measurements)
        XCTAssertNil(SentrySDK.appStartMeasurement)
    }
    
    func testAddWarmAppStartMeasurement_GetsPutOnNextTransaction() {
        SentrySDK.appStartMeasurement = SentryAppStartMeasurement(type: "warm", duration: 0.5)
        
        fixture.sut.finish()
        fixture.hub.group.wait()
        
        XCTAssertEqual(1, fixture.hub.capturedEventsWithScopes.count)
        let serializedTransaction = fixture.hub.capturedEventsWithScopes.first!.event.serialize()
        let measurements = serializedTransaction["measurements"] as? [String: [String: Int]]
        
        XCTAssertEqual(["app_start_warm": ["value": 500]], measurements)
        XCTAssertNil(SentrySDK.appStartMeasurement)
    }
    
    func testAddGarbageAppStartMeasurement_GetsNotPutOnNextTransaction() {
        SentrySDK.appStartMeasurement = SentryAppStartMeasurement(type: "b", duration: 0.5)
        
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
        SentrySDK.appStartMeasurement = SentryAppStartMeasurement(type: "warm", duration: 0.5)
        
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
    
    func testAddFramesMeasurement() {
        SentryFramesTracker.sharedInstance().start()
        let sut = fixture.sut
        
        let slowFrames = 4
        let frozenFrames = 1
        let totalFrames = 100
        givenFrames(slowFrames, frozenFrames, totalFrames)
        
        sut.finish()
        
        fixture.hub.group.wait()
        
        XCTAssertEqual(1, fixture.hub.capturedEventsWithScopes.count)
        
        XCTAssertEqual(1, fixture.hub.capturedEventsWithScopes.count)
        let serializedTransaction = fixture.hub.capturedEventsWithScopes.first!.event.serialize()
        let measurements = serializedTransaction["measurements"] as? [String: [String: Int]]
        
        XCTAssertEqual([
            "frames_total": ["value": totalFrames],
            "frames_slow": ["value": slowFrames],
            "frames_frozen": ["value": frozenFrames]
        ], measurements)
        XCTAssertNil(SentrySDK.appStartMeasurement)
    }
    
    private func givenFrames(_ slow: Int, _ frozen: Int, _ total: Int) {
        
        fixture.displayLinkWrapper.call()
        
        //Slow frames
        for _ in 0..<slow {
            fixture.displayLinkWrapper.internalTimestamp += TestData.slowFrameThreshold + 0.001
            fixture.displayLinkWrapper.call()
        }
        
        // Frozen frames
        for _ in 0..<frozen {
            fixture.displayLinkWrapper.internalTimestamp += TestData.frozenFrameThreshold + 0.001
            fixture.displayLinkWrapper.call()
        }
        
        // Normal frames
        for _ in 0..<(total - slow - frozen) {
            fixture.displayLinkWrapper.internalTimestamp += TestData.slowFrameThreshold - 1
            fixture.displayLinkWrapper.call()
        }
    }
}
