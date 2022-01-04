import Sentry
import XCTest

class SentryAutoBreadcrumbTrackingIntegrationTests: XCTestCase {
    
    private class Fixture {
        let tracker = SentryTestBreadcrumbTracker()
        
        var sut: SentryAutoBreadcrumbTrackingIntegration {
            return SentryAutoBreadcrumbTrackingIntegration()
        }
    }
    
    private var fixture: Fixture!
    
    override func setUp() {
        super.setUp()
        fixture = Fixture()
    }

    func testInstallWithSwizzleEnabled_StartSwizzleCalled() {
        let sut = fixture.sut
        
        sut.install(with: Options(), breadcrumbTracker: fixture.tracker, systemEventBreadcrumbs: SentrySystemEventBreadcrumbs())
        
        XCTAssertEqual(1, fixture.tracker.startInvocations.count)
        XCTAssertEqual(1, fixture.tracker.startSwizzleInvocations.count)
    }
    
    func testInstallWithSwizzleDisabled_StartSwizzleNotCalled() {
        let sut = fixture.sut
        
        let options = Options()
        options.enableSwizzling = false
        sut.install(with: options, breadcrumbTracker: fixture.tracker, systemEventBreadcrumbs: SentrySystemEventBreadcrumbs())
        
        XCTAssertEqual(1, fixture.tracker.startInvocations.count)
        XCTAssertEqual(0, fixture.tracker.startSwizzleInvocations.count)
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
