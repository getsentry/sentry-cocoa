import Sentry
import XCTest

class SentryAutoBreadcrumbTrackingIntegrationTests: XCTestCase {
    
    private class Fixture {
        let tracker = SentryTestBreadcrumbTracker(swizzleWrapper: SentrySwizzleWrapper.sharedInstance)
        
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

    func testInstallWithSwizzleEnabled_StartSwizzleCalled() {
        let sut = fixture.sut
        
        sut.install(with: Options(), breadcrumbTracker: fixture.tracker, systemEventBreadcrumbs: SentrySystemEventBreadcrumbs(fileManager: SentryDependencyContainer.sharedInstance().fileManager, andCurrentDateProvider: DefaultCurrentDateProvider.sharedInstance()))
        
        XCTAssertEqual(1, fixture.tracker.startInvocations.count)
        XCTAssertEqual(1, fixture.tracker.startSwizzleInvocations.count)
    }
    
    func testInstallWithSwizzleDisabled_StartSwizzleNotCalled() {
        let sut = fixture.sut
        
        let options = Options()
        options.enableSwizzling = false
        sut.install(with: options, breadcrumbTracker: fixture.tracker, systemEventBreadcrumbs: SentrySystemEventBreadcrumbs(fileManager: SentryDependencyContainer.sharedInstance().fileManager, andCurrentDateProvider: DefaultCurrentDateProvider.sharedInstance()))
        
        XCTAssertEqual(1, fixture.tracker.startInvocations.count)
        XCTAssertEqual(0, fixture.tracker.startSwizzleInvocations.count)
    }

    func test_enableAutoBreadcrumbTracking_Disabled() {
        let options = Options()
        options.enableAutoBreadcrumbTracking = false

        let sut = SentryAutoBreadcrumbTrackingIntegration()
        let result = sut.install(with: options)

        XCTAssertFalse(result)
    }
}

private class SentryTestBreadcrumbTracker: SentryBreadcrumbTracker {
    
    let startInvocations = Invocations<Void>()
    override func start() {
        startInvocations.record(Void())
    }
    
    let startSwizzleInvocations = Invocations<Void>()
    override func startSwizzle() {
        startSwizzleInvocations.record(Void())
    }
    
}
