import Sentry
import SentryTestUtils
import XCTest

class SentryAutoBreadcrumbTrackingIntegrationTests: XCTestCase {
    
    private class Fixture {
        let breadcrumbTracker = SentryTestBreadcrumbTracker()
        
#if os(iOS)
        var systemEventBreadcrumbTracker: SentryTestSystemEventBreadcrumbs?
        var memoryBreadcrumbTracker: SentryTestMemoryEventBreadcrumbs?
#endif // os(iOS)
        
        var sut: SentryAutoBreadcrumbTrackingIntegration {
            return SentryAutoBreadcrumbTrackingIntegration()
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
    
#if os(iOS)
    func testInstallWithSwizzleEnabled_StartSwizzleCalled() throws {
        let sut = fixture.sut
        
        try self.install(sut: sut)
        
        XCTAssertEqual(1, fixture.breadcrumbTracker.startInvocations.count)
        XCTAssertEqual(1, fixture.breadcrumbTracker.startSwizzleInvocations.count)
    }
    
    func testInstallWithSwizzleDisabled_StartSwizzleNotCalled() throws {
        let sut = fixture.sut
        
        let options = Options()
        options.enableSwizzling = false
        
        try self.install(sut: sut, options: options)
        
        XCTAssertEqual(1, fixture.breadcrumbTracker.startInvocations.count)
        XCTAssertEqual(0, fixture.breadcrumbTracker.startSwizzleInvocations.count)
    }
#endif // os(iOS)

    func test_enableAutoBreadcrumbTracking_Disabled() {
        let options = Options()
        options.enableAutoBreadcrumbTracking = false

        let sut = SentryAutoBreadcrumbTrackingIntegration()
        let result = sut.install(with: options)

        XCTAssertFalse(result)
    }
    
#if os(iOS)
    func testInstall() throws {
        let options = Options()
        
        let sut = SentryAutoBreadcrumbTrackingIntegration()
        try self.install(sut: sut, options: options)
        
        let scope = Scope()
        let hub = SentryHub(client: TestClient(options: Options()), andScope: scope)
        SentrySDK.setCurrentHub(hub)
        
        let crumb = TestData.crumb
        fixture.systemEventBreadcrumbTracker?.startWithDelegateInvocations.first?.add(crumb)
        
        let otherCrumb = TestData.crumb
        fixture.memoryBreadcrumbTracker?.startWithDelegateInvocations.first?.add(otherCrumb)
        
        let serializedScope = scope.serialize()
                
        XCTAssertNotNil(serializedScope["breadcrumbs"] as? [[String: Any]], "no scope.breadcrumbs")
        
        if let breadcrumbs = serializedScope["breadcrumbs"] as? [[String: Any]] {
            XCTAssertNotNil(breadcrumbs.first, "scope.breadcrumbs is empty")
            if let actualCrumb = breadcrumbs.first {
                XCTAssertEqual(crumb.category, actualCrumb["category"] as? String)
                XCTAssertEqual(crumb.type, actualCrumb["type"] as? String)
            }
            
            XCTAssertNotNil(breadcrumbs[1], "scope.breadcrumbs is empty")
            let actualCrumb = breadcrumbs[1]
            XCTAssertEqual(otherCrumb.category, actualCrumb["category"] as? String)
            XCTAssertEqual(otherCrumb.type, actualCrumb["type"] as? String)
        }
    }
#endif // os(iOS)
    
    private func install(sut: SentryAutoBreadcrumbTrackingIntegration, options: Options = Options()) throws {
        
#if os(iOS)
        fixture.systemEventBreadcrumbTracker = SentryTestSystemEventBreadcrumbs(fileManager: try TestFileManager(options: options), andNotificationCenterWrapper: TestNSNotificationCenterWrapper())
        fixture.memoryBreadcrumbTracker = SentryTestMemoryEventBreadcrumbs()
        sut.install(with: options, breadcrumbTracker: fixture.breadcrumbTracker, systemEventBreadcrumbs: fixture.systemEventBreadcrumbTracker!, memoryEventBreadcrumbs: fixture.memoryBreadcrumbTracker!)
#else
        sut.install(with: options, breadcrumbTracker: fixture.breadcrumbTracker)
#endif // os(iOS)
        
    }
}

private class SentryTestBreadcrumbTracker: SentryBreadcrumbTracker {
    
    let startInvocations = Invocations<SentryBreadcrumbDelegate>()
    override func start(with delegate: SentryBreadcrumbDelegate) {
        startInvocations.record(delegate)
    }
    
#if os(iOS)
    let startSwizzleInvocations = Invocations<Void>()
    override func startSwizzle() {
        startSwizzleInvocations.record(Void())
    }
#endif // os(iOS)

}

#if os(iOS)

private class SentryTestSystemEventBreadcrumbs: SentrySystemEventBreadcrumbs {
    
    let startWithDelegateInvocations = Invocations<SentryBreadcrumbDelegate>()
    override func start(with delegate: SentryBreadcrumbDelegate) {
        startWithDelegateInvocations.record(delegate)
    }
}

private class SentryTestMemoryEventBreadcrumbs: SentryMemoryEventBreadcrumbs {
    
    let startWithDelegateInvocations = Invocations<SentryBreadcrumbDelegate>()
    override func start(with delegate: SentryBreadcrumbDelegate) {
        startWithDelegateInvocations.record(delegate)
    }
}

#endif // os(iOS)
