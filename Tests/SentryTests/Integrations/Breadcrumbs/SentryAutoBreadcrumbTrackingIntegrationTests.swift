@_spi(Private) import _SentryPrivate
@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryAutoBreadcrumbTrackingIntegrationTests: XCTestCase {
    
    private class Fixture {
        private let dateProvider = TestCurrentDateProvider()
        private let dispatchQueueWrapper = TestSentryDispatchQueueWrapper()

        let fileManager: TestFileManager
        let notificationCenterWrapper = TestNSNotificationCenterWrapper()
        let defaultOptions: Options

        init() throws {
            let options = Options()
            options.dsn = TestConstants.dsnForTestCase(type: SentryAutoBreadcrumbTrackingIntegrationTests.self)
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
        
        let crumb = TestData.crumb
        SentrySDKInternal.addBreadcrumb(crumb)
        
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
}
