@_spi(Private) import _SentryPrivate
@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryBreadcrumbTrackingIntegrationTests: XCTestCase {
    
    private class Fixture {
        private let dateProvider = TestCurrentDateProvider()
        private let dispatchQueueWrapper = TestSentryDispatchQueueWrapper()

        let fileManager: TestFileManager
        let notificationCenterWrapper = TestNSNotificationCenterWrapper()
        let defaultOptions: Options

        init() throws {
            let options = Options()
            options.dsn = TestConstants.dsnForTestCase(type: SentryBreadcrumbTrackingIntegrationTests.self)
            options.enableAutoBreadcrumbTracking = true
            defaultOptions = options

            fileManager = try TestFileManager(
                options: options,
                dateProvider: dateProvider,
                dispatchQueueWrapper: dispatchQueueWrapper
            )
        }

        func getSut(options: Options? = nil) throws -> SentryAutoBreadcrumbTrackingIntegration<SentryDependencyContainer> {
            let container = SentryDependencyContainer.sharedInstance()
            container.fileManager = fileManager
            container.notificationCenterWrapper = notificationCenterWrapper
            
            return try XCTUnwrap(SentryAutoBreadcrumbTrackingIntegration(
                with: options ?? defaultOptions,
                dependencies: container
            ))
        }
    }
    
    private var fixture: Fixture!

    override func setUpWithError() throws {
        try super.setUpWithError()
        fixture = try Fixture()
        
        // Ignore the reachability callbacks, so we don't get connectivity breadcrumbs.
        SentryDependencyContainer.sharedInstance().reachability.setReachabilityIgnoreActualCallback(true)
    }

    override func tearDown() {
        super.tearDown()
        clearTestState()
    }
    
    func test_enableAutoBreadcrumbTracking_Disabled() {
        let options = Options()
        options.enableAutoBreadcrumbTracking = false

        let container = SentryDependencyContainer.sharedInstance()
        container.fileManager = fixture.fileManager
        container.notificationCenterWrapper = fixture.notificationCenterWrapper
        
        let sut = SentryAutoBreadcrumbTrackingIntegration(with: options, dependencies: container)

        XCTAssertNil(sut, "Integration should return nil when enableAutoBreadcrumbTracking is disabled")
    }
    
    func testInstall() throws {
        let sut = try fixture.getSut()
        defer {
            sut.uninstall()
        }
        
        let scope = Scope()
        let hub = SentryHubInternal(client: TestClient(options: Options()), andScope: scope)
        SentrySDKInternal.setCurrentHub(hub)
        // Make sure there are no other breadcrumbs in the scope
        scope.clearBreadcrumbs()
        
        // Add a sample breadcrumb
        let crumb = TestData.crumb
        sut.add(crumb)
        
        let serializedScope = scope.serialize()
        let breadcrumbs = try XCTUnwrap(serializedScope["breadcrumbs"] as? [[String: Any]], "no scope.breadcrumbs")
        XCTAssertEqual(1, breadcrumbs.count)
        XCTAssertEqual(crumb.category, try XCTUnwrap(breadcrumbs[0]["category"] as? String))
        XCTAssertEqual(crumb.type, try XCTUnwrap(breadcrumbs[0]["type"] as? String))
    }
}
