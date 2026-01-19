@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst) || os(visionOS)
class SentryFramesTrackingIntegrationTests: XCTestCase {

    private struct MockFramesTrackingProvider: FramesTrackingProvider {
        var framesTracker: SentryFramesTracker
    }

    private class Fixture {
        let options = Options()
        let displayLink = TestDisplayLinkWrapper()
        let framesTracker = SentryDependencyContainer.sharedInstance().framesTracker

        init() {
            options.dsn = TestConstants.dsnAsString(username: "SentryFramesTrackingIntegrationTests")
        }

        var dependencies: MockFramesTrackingProvider {
            MockFramesTrackingProvider(framesTracker: framesTracker)
        }
    }

    private let fixture = Fixture()

    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        PrivateSentrySDKOnly.framesTrackingMeasurementHybridSDKMode = false
        clearTestState()
        super.tearDown()
    }
    
    func testTracesSampleRateSet_MeasuresFrames() {
        let options = fixture.options
        options.tracesSampleRate = 0.1
        let sut = SentryFramesTrackingIntegration(with: options, dependencies: fixture.dependencies)
        defer {
            sut?.uninstall()
        }

        XCTAssertNotNil(sut)
        XCTAssertNotNil(sut?.tracker)
    }

    func testTracesSamplerSet_MeasuresFrames() {
        let options = fixture.options
        options.tracesSampler = { _ in return 0 }
        let sut = SentryFramesTrackingIntegration(with: options, dependencies: fixture.dependencies)
        defer {
            sut?.uninstall()
        }

        XCTAssertNotNil(sut)
        XCTAssertNotNil(sut?.tracker)
    }

    func testAppHangEnabled_MeasuresFrames() {
        let options = fixture.options
        let sut = SentryFramesTrackingIntegration(with: options, dependencies: fixture.dependencies)
        defer {
            sut?.uninstall()
        }

        XCTAssertNotNil(sut)
        XCTAssertNotNil(sut?.tracker)
    }

    func testAppHangEnabled_ButIntervalZero_DoestNotMeasuresFrames() {
        let options = fixture.options
        options.appHangTimeoutInterval = 0.0
        options.enableWatchdogTerminationTracking = false
        let sut = SentryFramesTrackingIntegration(with: options, dependencies: fixture.dependencies)
        defer {
            sut?.uninstall()
        }

        XCTAssertNil(sut)
    }

    func testZeroTracesSampleRate_DoesNotMeasureFrames() {
        let options = fixture.options
        options.tracesSampleRate = 0.0
        options.appHangTimeoutInterval = 0.0
        options.enableWatchdogTerminationTracking = false
        let sut = SentryFramesTrackingIntegration(with: options, dependencies: fixture.dependencies)
        defer {
            sut?.uninstall()
        }

        XCTAssertNil(sut)
    }

    func testAutoPerformanceTrackingDisabled_DoesNotMeasureFrames() {
        let options = fixture.options
        options.tracesSampleRate = 0.1
        options.enableAutoPerformanceTracing = false
        options.enableAppHangTracking = false
        options.enableWatchdogTerminationTracking = false
        let sut = SentryFramesTrackingIntegration(with: options, dependencies: fixture.dependencies)
        defer {
            sut?.uninstall()
        }

        XCTAssertNil(sut)
    }

    func test_HybridSDKEnables_MeasureFrames() {
        PrivateSentrySDKOnly.framesTrackingMeasurementHybridSDKMode = true

        let options = fixture.options
        options.enableAutoPerformanceTracing = false
        let sut = SentryFramesTrackingIntegration(with: options, dependencies: fixture.dependencies)
        defer {
            sut?.uninstall()
        }

        XCTAssertNotNil(sut)
        XCTAssertNotNil(sut?.tracker)
    }

    func testUninstall() throws {
        let sut = try XCTUnwrap(SentryFramesTrackingIntegration(with: fixture.options, dependencies: fixture.dependencies))

        SentryDependencyContainer.sharedInstance().framesTracker.setDisplayLinkWrapper(fixture.displayLink)

        sut.uninstall()

        XCTAssertNil(fixture.displayLink.target)
        XCTAssertNil(fixture.displayLink.selector)
    }
}
#endif
