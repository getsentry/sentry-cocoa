@_spi(Private) import _SentryPrivate
@_spi(Private) @testable import Sentry
import SentryTestUtils
import XCTest

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
class SentryPerformanceTrackingIntegrationTests: XCTestCase {
    private class Fixture {
        let defaultOptions: Options

        init() {
            let options = Options()
            options.tracesSampleRate = 0.1
            defaultOptions = options
        }

        func getSut(options: Options? = nil) -> SentryPerformanceTrackingIntegration<SentryDependencyContainer>? {
            let container = SentryDependencyContainer.sharedInstance()
            return SentryPerformanceTrackingIntegration(
                with: options ?? defaultOptions,
                dependencies: container
            )
        }
    }

    private var fixture: Fixture!

    override func setUp() {
        super.setUp()
        fixture = Fixture()
    }

    override func tearDown() {
        super.tearDown()
        SentryDependencyContainer.reset()
    }

    func testSwizzlingInitialized_WhenAPMandTracingEnabled() throws {
        let sut = try XCTUnwrap(fixture.getSut())
        defer {
            sut.uninstall()
        }

        XCTAssertNotNil(Dynamic(sut).swizzling.asObject)
    }

    func testSwizzlingNotInitialized_WhenTracingDisabled() {
        let options = Options()
        let sut = fixture.getSut(options: options)

        XCTAssertNil(sut)
    }

    func testSwizzlingNotInitialized_WhenAPMDisabled() {
        let options = Options()
        options.tracesSampleRate = 0.1
        options.enableAutoPerformanceTracing = false
        let sut = fixture.getSut(options: options)

        XCTAssertNil(sut)
    }

    func testSwizzlingNotInitialized_WhenSwizzlingDisabled() {
        let options = Options()
        options.tracesSampleRate = 0.1
        options.enableSwizzling = false
        let sut = fixture.getSut(options: options)

        XCTAssertNil(sut)
    }

    func testAutoPerformanceDisabled() {
        let options = Options()
        options.enableAutoPerformanceTracing = false

        disablesIntegration(options)
    }

    func testUIViewControllerDisabled() {
        let options = Options()
        options.enableUIViewControllerTracing = false

        disablesIntegration(options)
    }

    private func disablesIntegration(_ options: Options) {
        let sut = fixture.getSut(options: options)

        XCTAssertNil(sut)
    }

    func testConfigure_waitForDisplay() throws {
        let options = Options()
        options.tracesSampleRate = 0.1
        options.enableTimeToFullDisplayTracing = true

        let sut = try XCTUnwrap(fixture.getSut(options: options))
        defer {
            sut.uninstall()
        }

        let performanceTracker = SentryDependencyContainer.sharedInstance().uiViewControllerPerformanceTracker
        XCTAssertTrue(performanceTracker.alwaysWaitForFullDisplay)
    }

    func testConfigure_dontWaitForDisplay() throws {
        let options = Options()
        options.tracesSampleRate = 0.1
        options.enableTimeToFullDisplayTracing = false

        let sut = try XCTUnwrap(fixture.getSut(options: options))
        defer {
            sut.uninstall()
        }

        let performanceTracker = SentryDependencyContainer.sharedInstance().uiViewControllerPerformanceTracker
        XCTAssertFalse(performanceTracker.alwaysWaitForFullDisplay)
    }
}
#endif
