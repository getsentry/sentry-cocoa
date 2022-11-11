import Sentry
import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class SentryUIEventTrackerIntegrationTests: XCTestCase {
    
    private class Fixture {
          
        func getSut() -> SentryUIEventTrackingIntegration {
            return SentryUIEventTrackingIntegration()
        }
        
        func optionForUIEventTracking(enableSwizzling: Bool = true, enableAutoPerformanceTracking: Bool = true, enableUserInteractionTracing: Bool = true, tracesSampleRate: Double = 1.0) -> Options {
            let res = Options()
            res.enableSwizzling = enableSwizzling
            res.enableAutoPerformanceTracking = enableAutoPerformanceTracking
            res.enableUserInteractionTracing = enableUserInteractionTracing
            res.tracesSampleRate = NSNumber(value: tracesSampleRate)
            return res
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
    
    func test_noInstallation_SwizzlingDisabled() {
        let sut = fixture.getSut()
        sut.install(with: fixture.optionForUIEventTracking(enableSwizzling: false))
        assertNoInstallation(sut)
        XCTAssertFalse(SentrySwizzleWrapper.hasItems())
    }
    
    func test_noInstallation_AutoPerformanceDisabled() {
        let sut = fixture.getSut()
        sut.install(with: fixture.optionForUIEventTracking(enableAutoPerformanceTracking: false))
        assertNoInstallation(sut)
        XCTAssertFalse(SentrySwizzleWrapper.hasItems())
    }
    
    func test_noInstallation_UserInteractionDisabled() {
        let sut = fixture.getSut()
        sut.install(with: fixture.optionForUIEventTracking(enableUserInteractionTracing: false))
        assertNoInstallation(sut)
        XCTAssertFalse(SentrySwizzleWrapper.hasItems())
    }
    
    func test_noInstallation_NoSampleRate() {
        let sut = fixture.getSut()
        sut.install(with: fixture.optionForUIEventTracking(tracesSampleRate: 0))
        assertNoInstallation(sut)
        XCTAssertFalse(SentrySwizzleWrapper.hasItems())
    }
    
    func test_Installation() {
        let sut = fixture.getSut()
        sut.install(with: fixture.optionForUIEventTracking())
        XCTAssertNotNil(Dynamic(sut).uiEventTracker as SentryUIEventTracker?)
        XCTAssertTrue(SentrySwizzleWrapper.hasItems())
    }
    
    func test_Uninstall() {
        let sut = fixture.getSut()
        sut.install(with: fixture.optionForUIEventTracking())
        XCTAssertNotNil(Dynamic(sut).uiEventTracker as SentryUIEventTracker?)
        XCTAssertTrue(SentrySwizzleWrapper.hasItems())
        
        sut.uninstall()
        
        XCTAssertFalse(SentrySwizzleWrapper.hasItems())
    }
    
    func assertNoInstallation(_ integration: SentryUIEventTrackingIntegration) {
        XCTAssertNil(Dynamic(integration).uiEventTracker as SentryUIEventTracker?)
    }
    
}
#endif
