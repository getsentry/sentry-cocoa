import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class SentryAppStartTrackingIntegrationTests: NotificationCenterTestCase {
    
    private class Fixture {
        let options = Options()
        let fileManager: SentryFileManager
        
        init() {
            options.tracesSampleRate = 0.1
            options.tracesSampler = { _ in return 0 } 
            options.dsn = TestConstants.dsnAsString(username: "SentryAppStartTrackingIntegrationTests")
            
            fileManager = TestFileManager(options: options)
        }
    }
    
    private var fixture: Fixture!
    private var sut: SentryAppStartTrackingIntegration!
    
    override func setUp() {
        super.setUp()
        fixture = Fixture()
        SentrySDK.setAppStartMeasurement(nil)
        sut = SentryAppStartTrackingIntegration()
    }

    override func tearDown() {
        super.tearDown()
        fixture.fileManager.deleteAppState()
        PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode = false
        SentrySDK.setAppStartMeasurement(nil)
        sut.stop()
    }
    
    func testAppStartMeasuringEnabledAndSampleRate_DoesUpdatesAppState() {
        sut.install(with: fixture.options)
        
        uiWindowDidBecomeVisible()
        
        XCTAssertNotNil(SentrySDK.getAppStartMeasurement())
    }
    
    func testNoSampleRate_DoesNotUpdatesAppState() {
        let options = fixture.options
        options.tracesSampleRate = 0.0
        options.tracesSampler = nil
        sut.install(with: options)
        
        uiWindowDidBecomeVisible()
        
        XCTAssertNil(SentrySDK.getAppStartMeasurement())
    }
    
    func testHybridSDKModeEnabled_DoesUpdatesAppState() {
        PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode = true
        
        let options = fixture.options
        options.tracesSampleRate = 0.0
        options.tracesSampler = nil
        sut.install(with: options)
        
        uiWindowDidBecomeVisible()
        
        XCTAssertNotNil(SentrySDK.getAppStartMeasurement())
    }
    
    func testOnlyAppStartMeasuringEnabled_DoesNotUpdatesAppState() {
        let options = fixture.options
        options.tracesSampleRate = 0.0
        options.tracesSampler = nil
        sut.install(with: options)
        
        uiWindowDidBecomeVisible()
        
        XCTAssertNil(SentrySDK.getAppStartMeasurement())
    }
    
    func testAutoPerformanceTrackingDisabled_DoesNotUpdatesAppState() {
        let options = fixture.options
        options.enableAutoPerformanceTracking = false
        sut.install(with: options)
        
        uiWindowDidBecomeVisible()
        
        XCTAssertNil(SentrySDK.getAppStartMeasurement())
    }
    
    func test_PerformanceTrackingDisabled() {
        let options = fixture.options
        options.enableAutoPerformanceTracking = false
        let result = sut.install(with: options)
        
        XCTAssertFalse(result)
    }
    
}
#endif
