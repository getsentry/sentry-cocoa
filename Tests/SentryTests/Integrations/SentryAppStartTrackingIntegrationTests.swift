import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class SentryAppStartTrackingIntegrationTests: XCTestCase {
    
    private class Fixture {
        let options = Options()
        let fileManager: SentryFileManager
        
        init() {
            options.enableAppStartMeasuring = true
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
    
    func testAppStartMeasuringEnabled_UpdatesAppState() {
        let sut = SentryAppStartTrackingIntegration()
        sut.install(with: fixture.options)
        
        TestNotificationCenter.didBecomeActive()
        
        XCTAssertNotNil(SentrySDK.appStartMeasurement)
    }
    
    func testAppStartMeasuringDisabled_DoesNotUpdatesAppState() {
        let sut = SentryAppStartTrackingIntegration()
        let options = fixture.options
        options.enableAppStartMeasuring = false
        sut.install(with: options)
        
        TestNotificationCenter.didBecomeActive()
        
        XCTAssertNil(SentrySDK.appStartMeasurement)
    }
    
    func testUninstall() {
        let sut = SentryAppStartTrackingIntegration()
        sut.install(with: fixture.options)
        
        sut.uninstall()
        
        TestNotificationCenter.didBecomeActive()
        
        XCTAssertNil(SentrySDK.appStartMeasurement)
    }
}
#endif
