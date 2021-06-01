import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class SentryAppStartTrackingIntegrationTests: XCTestCase {
    
    private class Fixture {
        let options = Options()
        let fileManager: SentryFileManager
        
        init() {
            options.enableAppStartMeasuring = true
            options.tracesSampleRate = 0.1
            options.dsn = TestConstants.dsnAsString(username: "SentryAppStartTrackingIntegrationTests")
            
            fileManager = try! SentryFileManager(options: options, andCurrentDateProvider: TestCurrentDateProvider())
            
        }
    }
    
    private var fixture: Fixture!
    
    override func setUp() {
        fixture = Fixture()
    }

    override func tearDown() {
        SentrySDK.appStartMeasurement = nil
        fixture.fileManager.deleteAppState()
    }
    
    func testAppStartMeasuringEnabledAndSampleRate_DoesUpdatesAppState() {
        let sut = SentryAppStartTrackingIntegration()
        sut.install(with: fixture.options)
        
        TestNotificationCenter.uiWindowDidBecomeVisible()
        
        XCTAssertNotNil(SentrySDK.appStartMeasurement)
    }
    
    func testOnlyAppStartMeasuringEnabled_DoesNotUpdatesAppState() {
        let sut = SentryAppStartTrackingIntegration()
        let options = fixture.options
        options.tracesSampleRate = 0.0
        sut.install(with: options)
        
        TestNotificationCenter.uiWindowDidBecomeVisible()
        
        XCTAssertNil(SentrySDK.appStartMeasurement)
    }
    
    func testAppStartMeasuringDisabled_DoesNotUpdatesAppState() {
        let sut = SentryAppStartTrackingIntegration()
        let options = fixture.options
        options.enableAppStartMeasuring = false
        sut.install(with: options)
        
        TestNotificationCenter.uiWindowDidBecomeVisible()
        
        XCTAssertNil(SentrySDK.appStartMeasurement)
    }
    
    func testUninstall() {
        let sut = SentryAppStartTrackingIntegration()
        sut.install(with: fixture.options)
        
        sut.uninstall()
        
        TestNotificationCenter.uiWindowDidBecomeVisible()
        
        XCTAssertNil(SentrySDK.appStartMeasurement)
    }
}
#endif
