@_spi(Private) import SentryTestUtils
@_spi(Private) @testable import Sentry
import XCTest

#if os(iOS) || os(tvOS) || os(visionOS)
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
        SentrySDKInternal.framesTrackingMeasurementHybridSDKMode = false
        // swiftlint:disable:next avoid_clear_test_state - just disabled to allow adding the SwiftLint rule. Please double check if you can remove this when touching this.
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

    #if !SDK_V10
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
    #endif // !SDK_V10

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
        #if !SDK_V10
        options.enableAppHangTracking = false
        #endif // !SDK_V10
        options.enableWatchdogTerminationTracking = false
        let sut = SentryFramesTrackingIntegration(with: options, dependencies: fixture.dependencies)
        defer {
            sut?.uninstall()
        }

        XCTAssertNil(sut)
    }

    func test_HybridSDKEnables_MeasureFrames() {
        // -- Arrange --
        let original = SentrySDKInternal.framesTrackingMeasurementHybridSDKMode
        SentrySDKInternal.framesTrackingMeasurementHybridSDKMode = true
        defer { SentrySDKInternal.framesTrackingMeasurementHybridSDKMode = original }

        // -- Act --

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
        fixture.options.tracesSampleRate = 0.1
        let sut = try XCTUnwrap(SentryFramesTrackingIntegration(with: fixture.options, dependencies: fixture.dependencies))

        SentryDependencyContainer.sharedInstance().framesTracker.setDisplayLinkWrapper(fixture.displayLink)

        sut.uninstall()

        XCTAssertNil(fixture.displayLink.target)
        XCTAssertNil(fixture.displayLink.selector)
    }
}
#endif
