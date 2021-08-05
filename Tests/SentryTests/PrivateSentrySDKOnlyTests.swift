import XCTest

class PrivateSentrySDKOnlyTests: XCTestCase {
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

    func testStoreEnvelope() {
        let client = TestClient(options: Options())
        SentrySDK.setCurrentHub(TestHub(client: client, andScope: nil))
        
        let envelope = TestConstants.envelope
        PrivateSentrySDKOnly.store(envelope)
        
        XCTAssertEqual(1, client?.storedEnvelopes.count)
        XCTAssertEqual(envelope, client?.storedEnvelopes.first)
    }
    
    func testCaptureEnvelope() {
        let client = TestClient(options: Options())
        SentrySDK.setCurrentHub(TestHub(client: client, andScope: nil))
        
        let envelope = TestConstants.envelope
        PrivateSentrySDKOnly.capture(envelope)
        
        XCTAssertEqual(1, client?.capturedEnvelopes.count)
        XCTAssertEqual(envelope, client?.capturedEnvelopes.first)
    }

    func testEnvelopeWithData() throws {
        let itemData = "{}\n{\"length\":0,\"type\":\"attachment\"}\n".data(using: .utf8)!
        XCTAssertNotNil(PrivateSentrySDKOnly.envelope(with: itemData))
    }
    
    func testGetDebugImages() {
        let sut = PrivateSentrySDKOnly()
        let images = sut.getDebugImages()
        
        // Only make sure we get some images. The actual tests are in
        // SentryDebugImageProviderTests
        XCTAssertGreaterThan(images.count, 100)
    }
    
    func testGetAppStartMeasurement() {
        let appStartMeasurement = TestData.getAppStartMeasurement(type: .warm)
        SentrySDK.setAppStartMeasurement(appStartMeasurement)
        
        XCTAssertEqual(appStartMeasurement, PrivateSentrySDKOnly.appStartMeasurement)
        
        SentrySDK.setAppStartMeasurement(nil)
        XCTAssertNil(PrivateSentrySDKOnly.appStartMeasurement)
    }
    
    func testSendAppStartMeasurement() {
        XCTAssertFalse(PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode)
        
        PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode = true
        XCTAssertTrue(PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode)
    }
    
    #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    
    func testIsFramesTrackingRunning() {
        XCTAssertFalse(PrivateSentrySDKOnly.isFramesTrackingRunning)
        SentryFramesTracker.sharedInstance().start()
        XCTAssertTrue(PrivateSentrySDKOnly.isFramesTrackingRunning)
    }
    
    func testGetFrames() {
        let tracker = SentryFramesTracker.sharedInstance()
        let displayLink = TestDiplayLinkWrapper()
        
        tracker.setDisplayLinkWrapper(displayLink)
        tracker.start()
        displayLink.call()
        
        let slow = 2
        let frozen = 1
        let normal = 100
        displayLink.givenFrames(slow, frozen, normal)
        
        let currentFrames = PrivateSentrySDKOnly.currentScreenFrames
        XCTAssertEqual(UInt(slow + frozen + normal), currentFrames.total)
        XCTAssertEqual(UInt(frozen), currentFrames.frozen)
        XCTAssertEqual(UInt(slow), currentFrames.slow)
    }

    #endif
}
