@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
final class FlushLogsIntegrationTests: XCTestCase {
    
    private static let dsnAsString = TestConstants.dsnAsString(username: "SentryLogFlushIntegrationTests")
    
    private class Fixture {
        let options: Options
        let client: TestClient
        let hub: SentryHubInternal
        let dependencies: SentryDependencyContainer
        let notificationCenterWrapper: TestNSNotificationCenterWrapper
        
        init() throws {
            options = Options()
            options.dsn = FlushLogsIntegrationTests.dsnAsString
            options.enableLogs = true
            
            client = TestClient(options: options)!
            hub = TestHub(client: client, andScope: nil)
            dependencies = SentryDependencyContainer.sharedInstance()
            notificationCenterWrapper = TestNSNotificationCenterWrapper()
            dependencies.notificationCenterWrapper = notificationCenterWrapper
        }
        
        func getSut() -> FlushLogsIntegration<SentryDependencyContainer>? {
            return FlushLogsIntegration(with: options, dependencies: dependencies)
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
        
        XCTAssertNotNil(sut)
    }
    
    func testInstall_FailsWhenLogsDisabled() {
        fixture.options.enableLogs = false
        
        let sut = fixture.getSut()
        
        XCTAssertNil(sut)
    }
    
    func testName_ReturnsCorrectName() {
        XCTAssertEqual(FlushLogsIntegration<SentryDependencyContainer>.name, "FlushLogsIntegration")
    }
    
    func testWillResignActive_FlushesLogs() {
        guard let sut = fixture.getSut() else {
            XCTFail("Integration should be initialized")
            return
        }
        // Keep sut alive so observers don't get deallocated
        _ = sut
        
        fixture.notificationCenterWrapper.post(Notification(name: CrossPlatformApplication.willResignActiveNotification))
        
        XCTAssertEqual(fixture.client.captureLogsInvocations.count, 1)
    }
    
    func testWillTerminate_FlushesLogs() {
        guard let sut = fixture.getSut() else {
            XCTFail("Integration should be initialized")
            return
        }
        // Keep sut alive so observers don't get deallocated
        _ = sut
        
        fixture.notificationCenterWrapper.post(Notification(name: CrossPlatformApplication.willTerminateNotification))
        
        XCTAssertEqual(fixture.client.captureLogsInvocations.count, 1)
    }
    
    func testUninstall_RemovesObservers() {
        guard let sut = fixture.getSut() else {
            XCTFail("Integration should be initialized")
            return
        }
        
        sut.uninstall()
        
        fixture.notificationCenterWrapper.post(Notification(name: CrossPlatformApplication.willResignActiveNotification))
        fixture.notificationCenterWrapper.post(Notification(name: CrossPlatformApplication.willTerminateNotification))
        
        // Should not flush logs after uninstall
        XCTAssertEqual(fixture.client.captureLogsInvocations.count, 0)
    }
    
    func testMultipleNotifications_FlushesLogsMultipleTimes() {
        guard let sut = fixture.getSut() else {
            XCTFail("Integration should be initialized")
            return
        }
        // Keep sut alive so observers don't get deallocated
        _ = sut
        
        fixture.notificationCenterWrapper.post(Notification(name: CrossPlatformApplication.willResignActiveNotification))
        fixture.notificationCenterWrapper.post(Notification(name: CrossPlatformApplication.willTerminateNotification))
        fixture.notificationCenterWrapper.post(Notification(name: CrossPlatformApplication.willResignActiveNotification))
        
        XCTAssertEqual(fixture.client.captureLogsInvocations.count, 3)
    }
}
#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
