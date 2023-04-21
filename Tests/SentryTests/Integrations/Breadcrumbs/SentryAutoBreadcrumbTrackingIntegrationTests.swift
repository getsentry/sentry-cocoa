import Sentry
import SentryTestUtils
import XCTest

class SentryAutoBreadcrumbTrackingIntegrationTests: XCTestCase {
    
    private class Fixture {
        let tracker = SentryTestBreadcrumbTracker(swizzleWrapper: SentrySwizzleWrapper.sharedInstance)
        
        var systemEventBreadcrumbs: SentryTestSystemEventBreadcrumbs?
        
        var sut: SentryAutoBreadcrumbTrackingIntegration {
            return SentryAutoBreadcrumbTrackingIntegration(crashWrapper: TestCrashWrapper())
        }
    }
    
    private var fixture: Fixture!
    
    override func setUp() {
        super.setUp()
        fixture = Fixture()
    }

    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

    func testInstallWithSwizzleEnabled_StartSwizzleCalled() throws {
        let sut = fixture.sut
        
        try self.install(sut: sut)
        
        XCTAssertEqual(1, fixture.tracker.startInvocations.count)
        XCTAssertEqual(1, fixture.tracker.startSwizzleInvocations.count)
    }
    
    func testInstallWithSwizzleDisabled_StartSwizzleNotCalled() throws {
        let sut = fixture.sut
        
        let options = Options()
        options.enableSwizzling = false
        
        try self.install(sut: sut, options: options)
        
        XCTAssertEqual(1, fixture.tracker.startInvocations.count)
        XCTAssertEqual(0, fixture.tracker.startSwizzleInvocations.count)
    }

    func test_enableAutoBreadcrumbTracking_Disabled() {
        let options = Options()
        options.enableAutoBreadcrumbTracking = false

        let sut = SentryAutoBreadcrumbTrackingIntegration(crashWrapper: TestCrashWrapper())
        let result = sut.install(with: options)

        XCTAssertFalse(result)
    }
    
    func testInstall() throws {
        let options = Options()
        
        let sut = SentryAutoBreadcrumbTrackingIntegration(crashWrapper: TestCrashWrapper())
        try self.install(sut: sut, options: options)
        
        let scope = Scope()
        let hub = SentryHub(client: TestClient(options: Options()), andScope: scope)
        SentrySDK.setCurrentHub(hub)
        
        let crumb = TestData.crumb
        fixture.systemEventBreadcrumbs?.startWithdelegateInvocations.first?.add(crumb)
        
        let serializedScope = scope.serialize()
                
        XCTAssertNotNil(serializedScope["breadcrumbs"] as? [[String: Any]], "no scope.breadcrumbs")
        
        if let breadcrumbs = serializedScope["breadcrumbs"] as? [[String: Any]] {
            XCTAssertNotNil(breadcrumbs.first, "scope.breadcrumbs is empty")
            if let actualCrumb = breadcrumbs.first {
                XCTAssertEqual(crumb.category, actualCrumb["category"] as? String)
                XCTAssertEqual(crumb.type, actualCrumb["type"] as? String)
            }
        }
    }
    
    private func install(sut: SentryAutoBreadcrumbTrackingIntegration, options: Options = Options()) throws {
        
        fixture.systemEventBreadcrumbs = SentryTestSystemEventBreadcrumbs(fileManager: try TestFileManager(options: options), andCurrentDateProvider: TestCurrentDateProvider(), andNotificationCenterWrapper: TestNSNotificationCenterWrapper())
        
        sut.install(with: options, breadcrumbTracker: fixture.tracker, systemEventBreadcrumbs: fixture.systemEventBreadcrumbs!)
    }
}

private class SentryTestBreadcrumbTracker: SentryBreadcrumbTracker {
    
    let startInvocations = Invocations<SentryBreadcrumbDelegate>()
    override func start(with delegate: SentryBreadcrumbDelegate) {
        startInvocations.record(delegate)
    }
    
    let startSwizzleInvocations = Invocations<Void>()
    override func startSwizzle() {
        startSwizzleInvocations.record(Void())
    }

}

private class SentryTestSystemEventBreadcrumbs: SentrySystemEventBreadcrumbs {
    
    let startWithdelegateInvocations = Invocations<SentryBreadcrumbDelegate>()
    override func start(with delegate: SentryBreadcrumbDelegate) {
        startWithdelegateInvocations.record(delegate)
    }
}
