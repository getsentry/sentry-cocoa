@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
final class SentryLogFlushIntegrationTests: XCTestCase {
    
    private static let dsnAsString = TestConstants.dsnAsString(username: "SentryLogFlushIntegrationTests")
    
    private class Fixture {
        let options: Options
        let client: TestClient
        let hub: SentryHubInternal
        
        init() throws {
            options = Options()
            options.dsn = SentryLogFlushIntegrationTests.dsnAsString
            options.enableLogs = true
            
            client = TestClient(options: options)!
            hub = TestHub(client: client, andScope: nil)
        }
        
        func getSut() -> SentryLogFlushIntegration {
            return SentryLogFlushIntegration()
        }
    }
    
    private var fixture: Fixture!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        fixture = try Fixture()
        SentrySDKInternal.setCurrentHub(fixture.hub)
    }
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }
    
    func testInstall_Success() {
        let sut = fixture.getSut()
        let result = sut.install(with: fixture.options)
        
        XCTAssertTrue(result)
    }
    
    func testInstall_FailsWhenLogsDisabled() {
        fixture.options.enableLogs = false
        
        let sut = fixture.getSut()
        let result = sut.install(with: fixture.options)
        
        XCTAssertFalse(result)
    }
    
    func testIntegrationOptions_ReturnsEnableLogs() {
        let sut = fixture.getSut()
        let options = sut.integrationOptions()
        
        XCTAssertEqual(options, .integrationOptionEnableLogs)
    }
    
    func testWillResignActive_FlushesLogs() {
        let sut = fixture.getSut()
        sut.install(with: fixture.options)
        
        NotificationCenter.default.post(Notification(name: CrossPlatformApplication.willResignActiveNotification))
        
        XCTAssertEqual(fixture.client.flushLogsInvocations.count, 1)
    }
    
    func testWillTerminate_FlushesLogs() {
        let sut = fixture.getSut()
        sut.install(with: fixture.options)
        
        NotificationCenter.default.post(Notification(name: CrossPlatformApplication.willTerminateNotification))
        
        XCTAssertEqual(fixture.client.flushLogsInvocations.count, 1)
    }
    
    func testUninstall_RemovesObservers() {
        let sut = fixture.getSut()
        sut.install(with: fixture.options)
        sut.uninstall()
        
        NotificationCenter.default.post(Notification(name: CrossPlatformApplication.willResignActiveNotification))
        NotificationCenter.default.post(Notification(name: CrossPlatformApplication.willTerminateNotification))
        
        // Should not flush logs after uninstall
        XCTAssertEqual(fixture.client.flushLogsInvocations.count, 0)
    }
    
    func testMultipleNotifications_FlushesLogsMultipleTimes() {
        let sut = fixture.getSut()
        sut.install(with: fixture.options)
        
        NotificationCenter.default.post(Notification(name: CrossPlatformApplication.willResignActiveNotification))
        NotificationCenter.default.post(Notification(name: CrossPlatformApplication.willTerminateNotification))
        NotificationCenter.default.post(Notification(name: CrossPlatformApplication.willResignActiveNotification))
        
        XCTAssertEqual(fixture.client.flushLogsInvocations.count, 3)
    }
}
#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
