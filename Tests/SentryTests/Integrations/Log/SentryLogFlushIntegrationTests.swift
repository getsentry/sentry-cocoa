@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class SentryLogFlushIntegrationTests: XCTestCase {
    
    private static let dsnAsString = TestConstants.dsnAsString(username: "SentryLogFlushIntegrationTests")
    
    private class Fixture {
        let dateProvider = TestCurrentDateProvider()
        let dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
        let notificationCenterWrapper = TestNSNotificationCenterWrapper()
        let options: Options
        let client: TestClient
        let hub: SentryHubInternal
        let fileManager: TestFileManager
        let appStateManager: SentryAppStateManager
        
        init() throws {
            options = Options()
            options.dsn = SentryLogFlushIntegrationTests.dsnAsString
            options.releaseName = TestData.appState.releaseName
            options.enableLogs = true
            
            fileManager = try TestFileManager(
                options: options,
                dateProvider: dateProvider,
                dispatchQueueWrapper: dispatchQueueWrapper
            )
            
            client = TestClient(options: options, fileManager: fileManager)
            hub = TestHub(client: client, andScope: nil)
            
            SentryDependencyContainer.sharedInstance().sysctlWrapper = TestSysctl()
            SentryDependencyContainer.sharedInstance().dispatchQueueWrapper = dispatchQueueWrapper
            SentryDependencyContainer.sharedInstance().notificationCenterWrapper = notificationCenterWrapper
            
            appStateManager = SentryAppStateManager(
                releaseName: options.releaseName,
                crashWrapper: TestSentryCrashWrapper(processInfoWrapper: ProcessInfo.processInfo),
                fileManager: fileManager,
                sysctlWrapper: SentryDependencyContainer.sharedInstance().sysctlWrapper
            )
            
            SentryDependencyContainer.sharedInstance().appStateManager = appStateManager
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
        fixture.appStateManager.stop(withForce: true)
        fixture.fileManager.deleteAppState()
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
    
    func testAppStateManagerWillResignActive_FlushesLogs() {
        let sut = fixture.getSut()
        sut.install(with: fixture.options)
        
        fixture.appStateManager.start()
        fixture.notificationCenterWrapper.post(Notification(name: CrossPlatformApplication.willResignActiveNotification))
        
        XCTAssertEqual(fixture.client.flushLogsInvocations.count, 1)
    }
    
    func testAppStateManagerWillTerminate_FlushesLogs() {
        let sut = fixture.getSut()
        sut.install(with: fixture.options)
        
        fixture.appStateManager.start()
        fixture.notificationCenterWrapper.post(Notification(name: CrossPlatformApplication.willTerminateNotification))
        
        XCTAssertEqual(fixture.client.flushLogsInvocations.count, 1)
    }
    
    func testUninstall_RemovesListener() {
        let sut = fixture.getSut()
        sut.install(with: fixture.options)
        
        fixture.appStateManager.start()
        sut.uninstall()
        
        fixture.notificationCenterWrapper.post(Notification(name: CrossPlatformApplication.willResignActiveNotification))
        fixture.notificationCenterWrapper.post(Notification(name: CrossPlatformApplication.willTerminateNotification))
        
        // Should not flush logs after uninstall
        XCTAssertEqual(fixture.client.flushLogsInvocations.count, 0)
    }
    
    func testMultipleAppStateChanges_FlushesLogsMultipleTimes() {
        let sut = fixture.getSut()
        sut.install(with: fixture.options)
        
        fixture.appStateManager.start()
        fixture.notificationCenterWrapper.post(Notification(name: CrossPlatformApplication.willResignActiveNotification))
        fixture.notificationCenterWrapper.post(Notification(name: CrossPlatformApplication.willTerminateNotification))
        fixture.notificationCenterWrapper.post(Notification(name: CrossPlatformApplication.willResignActiveNotification))
        
        XCTAssertEqual(fixture.client.flushLogsInvocations.count, 3)
    }
}
#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
