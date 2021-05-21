import XCTest

class SentryTracerTests: XCTestCase {
    
    private class Fixture {
        let hub = TestHub(client: nil, andScope: nil)
        
        #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        var displayLinkWrapper: TestDiplayLinkWrapper
        
        init() {
            displayLinkWrapper = TestDiplayLinkWrapper()
            
            SentryFramesTracker.sharedInstance().setDisplayLinkWrapper(displayLinkWrapper)
            SentryFramesTracker.sharedInstance().start()
            displayLinkWrapper.call()
        }
        #endif
        
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
        #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        SentryFramesTracker.sharedInstance().stop()
        #endif
    }

    func testAddColdAppStartMeasurement_GetsPutOnNextTransaction() {
        SentrySDK.appStartMeasurement = SentryAppStartMeasurement(type: "cold", duration: 0.5)
        
        fixture.sut.finish()
        fixture.hub.group.wait()
        
        XCTAssertEqual(1, fixture.hub.capturedEventsWithScopes.count)
        let serializedTransaction = fixture.hub.capturedEventsWithScopes.first!.event.serialize()
        let measurements = serializedTransaction["measurements"] as? [String: [String: Int]]
        
        XCTAssertEqual(addZeroFrames(measurements: ["app_start_cold": ["value": 500]]), measurements)
        XCTAssertNil(SentrySDK.appStartMeasurement)
    }
    
    func testAddWarmAppStartMeasurement_GetsPutOnNextTransaction() {
        SentrySDK.appStartMeasurement = SentryAppStartMeasurement(type: "warm", duration: 0.5)
        
        fixture.sut.finish()
        fixture.hub.group.wait()
        
        XCTAssertEqual(1, fixture.hub.capturedEventsWithScopes.count)
        let serializedTransaction = fixture.hub.capturedEventsWithScopes.first!.event.serialize()
        let measurements = serializedTransaction["measurements"] as? [String: [String: Int]]
        
        XCTAssertEqual(addZeroFrames(measurements: ["app_start_warm": ["value": 500]]), measurements)
        XCTAssertNil(SentrySDK.appStartMeasurement)
    }
    
    func testAddGarbageAppStartMeasurement_GetsNotPutOnNextTransaction() {
        SentrySDK.appStartMeasurement = SentryAppStartMeasurement(type: "b", duration: 0.5)
        
        fixture.sut.finish()
        fixture.hub.group.wait()
        
        XCTAssertEqual(1, fixture.hub.capturedEventsWithScopes.count)
        let serializedTransaction = fixture.hub.capturedEventsWithScopes.first!.event.serialize()
        
        #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        XCTAssertEqual(addZeroFrames(measurements: [:]), serializedTransaction["measurements"]  as? [String: [String: Int]])
        #else
        XCTAssertNil(serializedTransaction["measurements"])
        #endif
        
        XCTAssertNil(SentrySDK.appStartMeasurement)
    }
    
    // Altough we only run this test above the below specified versions, we exped the
    // implementation to be thread safe
    @available(tvOS 10.0, *)
    @available(OSX 10.12, *)
    @available(iOS 10.0, *)
    func testConcurrentTransactions_OnlyOneGetsAppStartMeasurement() {
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
            return measurements == addZeroFrames(measurements: ["app_start_warm": ["value": 500]])
        }.count
        
        XCTAssertEqual(1, transactionsWithAppStartMeasrurement)
        XCTAssertNil(SentrySDK.appStartMeasurement)
    }
    
    #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    func testAddFramesMeasurement() {
        let sut = fixture.sut
        
        let slowFrames = 4
        let frozenFrames = 1
        let normalFrames = 100
        let totalFrames = slowFrames + frozenFrames + normalFrames
        givenFrames(slowFrames, frozenFrames, normalFrames)
        
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
}
