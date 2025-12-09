@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
final class FlushLogsIntegrationTests: XCTestCase {
    
    private var options: Options!
    private var client: TestClient!
    private var hub: SentryHubInternal!
    private var dependencies: SentryDependencyContainer!
    private var notificationCenterWrapper: TestNSNotificationCenterWrapper!
    private var sut: FlushLogsIntegration<SentryDependencyContainer>?
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        options = Options()
        options.dsn = TestConstants.dsnForTestCase(type: FlushLogsIntegrationTests.self)
        options.enableLogs = true
        
        client = TestClient(options: options)!
        hub = TestHub(client: client, andScope: nil)
        dependencies = SentryDependencyContainer.sharedInstance()
        notificationCenterWrapper = TestNSNotificationCenterWrapper()
        dependencies.notificationCenterWrapper = notificationCenterWrapper
        
        SentrySDKInternal.setCurrentHub(hub)
    }
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
        sut = nil
    }
    
    func testInstall_Success() {
        sut = FlushLogsIntegration(with: options, dependencies: dependencies)
        XCTAssertNotNil(sut)
    }
    
    func testInstall_FailsWhenLogsDisabled() {
        options.enableLogs = false
        sut = FlushLogsIntegration(with: options, dependencies: dependencies)
        
        XCTAssertNil(sut)
    }
    
    func testName_ReturnsCorrectName() {
        sut = FlushLogsIntegration(with: options, dependencies: dependencies)
        
        XCTAssertEqual(FlushLogsIntegration<SentryDependencyContainer>.name, "FlushLogsIntegration")
    }
    
    func testWillResignActive_FlushesLogs() {
        sut = FlushLogsIntegration(with: options, dependencies: dependencies)
        
        notificationCenterWrapper.post(Notification(name: CrossPlatformApplication.willResignActiveNotification))
        
        XCTAssertEqual(client.captureLogsInvocations.count, 1)
    }
    
    func testWillTerminate_FlushesLogs() {
        sut = FlushLogsIntegration(with: options, dependencies: dependencies)
        
        notificationCenterWrapper.post(Notification(name: CrossPlatformApplication.willTerminateNotification))
        
        XCTAssertEqual(client.captureLogsInvocations.count, 1)
    }
    
    func testUninstall_RemovesObservers() {
        guard let sut = FlushLogsIntegration(with: options, dependencies: dependencies) else {
            XCTFail("Integration should be initialized")
            return
        }
        sut.uninstall()
        
        notificationCenterWrapper.post(Notification(name: CrossPlatformApplication.willResignActiveNotification))
        notificationCenterWrapper.post(Notification(name: CrossPlatformApplication.willTerminateNotification))
        
        // Should not flush logs after uninstall
        XCTAssertEqual(client.captureLogsInvocations.count, 0)
    }
    
    func testMultipleNotifications_FlushesLogsMultipleTimes() {
        sut = FlushLogsIntegration(with: options, dependencies: dependencies)
        
        notificationCenterWrapper.post(Notification(name: CrossPlatformApplication.willResignActiveNotification))
        notificationCenterWrapper.post(Notification(name: CrossPlatformApplication.willTerminateNotification))
        notificationCenterWrapper.post(Notification(name: CrossPlatformApplication.willResignActiveNotification))
        
        XCTAssertEqual(client.captureLogsInvocations.count, 3)
    }
}
#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
