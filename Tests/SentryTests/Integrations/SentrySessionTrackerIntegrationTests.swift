@testable import Sentry
import XCTest

class SentrySessionTrackerIntegrationTests: XCTestCase {

    private class Fixture {
        
        var currentDateProvider = TestCurrentDateProvider()
        var hub: SentryHub!
        var fileManager: SentryFileManager!
        
        init() {
            fileManager = try! SentryFileManager(dsn: SentryDsn())
        }
        
        func getSut() -> SessionTracker {
            let options = Options()
            options.dsn = TestConstants.dsnAsString
            options.releaseName = "SentrySessionTrackerIntegrationTests"
            options.sessionTrackingIntervalMillis = 10_000
            
            let client = TestClient(options: options)
            
            hub = SentryHub(client: client, andScope: nil)
            SentrySDK.setCurrentHub(hub)
            
            return SessionTracker(options: options, currentDateProvider: currentDateProvider)
        }
    }
    
    private var fixture: Fixture!

    override func setUp() {
        super.setUp()

        fixture = Fixture()
        fixture.fileManager.deleteCurrentSession()
        fixture.fileManager.deleteTimestampLastInForeground()
    }
    
    func testLaunchBackgroundExecutionDoesNotStoreSession() {
        fixture.getSut().start()
        TestNotificationCenter.didEnterBackground()
        
        XCTAssertNil(fixture.fileManager.readCurrentSession())
        XCTAssertNil(fixture.fileManager.readTimestampLastInForeground())
    }
    
    func testLaunchBackgroundExecutionFromForegroundStoresSession() {
        // Docs about background execution sequence https://developer.apple.com/documentation/uikit/app_and_environment/scenes/preparing_your_ui_to_run_in_the_background/about_the_background_execution_sequence
        
        fixture.getSut().start()
        TestNotificationCenter.didBecomeActive()
        TestNotificationCenter.willResignActive()
        TestNotificationCenter.didEnterBackground()
        
        XCTAssertNotNil(fixture.fileManager.readCurrentSession())
        XCTAssertNotNil(fixture.fileManager.readTimestampLastInForeground())
    }
    
}
