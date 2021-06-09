import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class SentryAppStartTrackingIntegrationTests: XCTestCase {
    
    private class Fixture {
        let options = Options()
        let fileManager: SentryFileManager
        
        init() {
            options.tracesSampleRate = 0.1
            options.tracesSampler = { _ in return 0 } 
            options.dsn = TestConstants.dsnAsString(username: "SentryAppStartTrackingIntegrationTests")
            
            fileManager = try! SentryFileManager(options: options, andCurrentDateProvider: TestCurrentDateProvider())
        }
    }
    
    private var fixture: Fixture!
    private var sut: SentryAppStartTrackingIntegration!
    
    override func setUp() {
        fixture = Fixture()
        SentrySDK.getAndResetAppStartMeasurement()
        sut = SentryAppStartTrackingIntegration()
    }

    override func tearDown() {
        fixture.fileManager.deleteAppState()
        sut.stop()
    }
    
    func testAppStartMeasuringEnabledAndSampleRate_DoesUpdatesAppState() {
        sut.install(with: fixture.options)
        
        TestNotificationCenter.uiWindowDidBecomeVisible()
        
        XCTAssertNotNil(SentrySDK.getAndResetAppStartMeasurement())
    }
    
    func testNoSampleRate_DoesNotUpdatesAppState() {
        let options = fixture.options
        options.tracesSampleRate = 0.0
        options.tracesSampler = nil
        sut.install(with: options)
        
        TestNotificationCenter.uiWindowDidBecomeVisible()
        
        XCTAssertNil(SentrySDK.getAndResetAppStartMeasurement())
    }
    
    func testOnlyAppStartMeasuringEnabled_DoesNotUpdatesAppState() {
        let options = fixture.options
        options.tracesSampleRate = 0.0
        sut.install(with: options)
        
        TestNotificationCenter.uiWindowDidBecomeVisible()
        
        XCTAssertNil(SentrySDK.getAndResetAppStartMeasurement())
    }
    
    func testAutoUIPerformanceTrackingDisabled_DoesNotUpdatesAppState() {
        let options = fixture.options
        options.enableAutoUIPerformanceTracking = false
        sut.install(with: options)
        
        TestNotificationCenter.uiWindowDidBecomeVisible()
        
        XCTAssertNil(SentrySDK.getAndResetAppStartMeasurement())
    }
    
    func testAppStartMeasuringDisabled_DoesNotUpdatesAppState() {
        let options = fixture.options
        options.enableAppStartMeasuring = false
        sut.install(with: options)
        
        TestNotificationCenter.uiWindowDidBecomeVisible()
        
        XCTAssertNil(SentrySDK.getAndResetAppStartMeasurement())
    }
    
}
#endif
