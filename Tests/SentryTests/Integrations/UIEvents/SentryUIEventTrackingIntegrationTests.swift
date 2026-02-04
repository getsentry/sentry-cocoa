@_spi(Private) @testable import Sentry
import SentryTestUtils
import XCTest

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
class SentryUIEventTrackerIntegrationTests: XCTestCase {

    private class Fixture {

        func getSut(options: Options? = nil) -> SentryUIEventTrackingIntegration<SentryDependencyContainer>? {
            let container = SentryDependencyContainer.sharedInstance()
            return SentryUIEventTrackingIntegration(
                with: options ?? optionForUIEventTracking(),
                dependencies: container
            )
        }

        func optionForUIEventTracking(enableSwizzling: Bool = true, enableAutoPerformanceTracing: Bool = true, enableUserInteractionTracing: Bool = true, tracesSampleRate: Double = 1.0) -> Options {
            let res = Options()
            res.enableSwizzling = enableSwizzling
            res.enableAutoPerformanceTracing = enableAutoPerformanceTracing
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
        let sut = fixture.getSut(options: fixture.optionForUIEventTracking(enableSwizzling: false))
        XCTAssertNil(sut)
        XCTAssertFalse(SentrySwizzleWrapper.hasCallbacks())
    }

    func test_noInstallation_AutoPerformanceDisabled() {
        let sut = fixture.getSut(options: fixture.optionForUIEventTracking(enableAutoPerformanceTracing: false))
        XCTAssertNil(sut)
        XCTAssertFalse(SentrySwizzleWrapper.hasCallbacks())
    }

    func test_noInstallation_UserInteractionDisabled() {
        let sut = fixture.getSut(options: fixture.optionForUIEventTracking(enableUserInteractionTracing: false))
        XCTAssertNil(sut)
        XCTAssertFalse(SentrySwizzleWrapper.hasCallbacks())
    }

    func test_noInstallation_NoSampleRate() {
        let sut = fixture.getSut(options: fixture.optionForUIEventTracking(tracesSampleRate: 0))
        XCTAssertNil(sut)
        XCTAssertFalse(SentrySwizzleWrapper.hasCallbacks())
    }
    
    func test_Installation() throws {
        let sut = try XCTUnwrap(fixture.getSut())
        XCTAssertTrue(SentrySwizzleWrapper.hasCallbacks())
        sut.uninstall()
    }

    func test_Uninstall() throws {
        let sut = try XCTUnwrap(fixture.getSut())
        XCTAssertTrue(SentrySwizzleWrapper.hasCallbacks())

        sut.uninstall()

        XCTAssertFalse(SentrySwizzleWrapper.hasCallbacks())
    }
    
}
#endif
