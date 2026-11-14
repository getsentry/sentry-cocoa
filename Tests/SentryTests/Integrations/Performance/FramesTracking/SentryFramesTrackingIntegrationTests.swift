@_spi(Private) import SentryTestUtils
#if SWIFT_PACKAGE && !SDK_V10
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import XCTest

#if os(iOS) || os(tvOS) || os(visionOS)
class SentryFramesTrackingIntegrationTests: XCTestCase {

    private struct MockFramesTrackingProvider: FramesTrackingProvider {
        var framesTracker: SentryFramesTracker

        func makeFrameSource(options: Options?) -> SentryFrameSource {
            SentryDependencyContainer.sharedInstance().makeFrameSource(options: options)
        }
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
        SentrySDK.internal.performance.framesTrackingHybridSDKMode = false
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

    func testAppHangEnabled_ButIntervalZero_ResetsToDefaultAndMeasuresFrames() {
        let options = fixture.options
        options.appHangTimeoutInterval = 0.0
        options.enableWatchdogTerminationTracking = false
        let sut = SentryFramesTrackingIntegration(with: options, dependencies: fixture.dependencies)
        defer {
            sut?.uninstall()
        }

        XCTAssertEqual(2.0, options.appHangTimeoutInterval)
        XCTAssertNotNil(sut)
    }
    #endif // !SDK_V10

    @available(*, deprecated, message: "Testing deprecated App Hang tracking option")
    func testZeroTracesSampleRate_DoesNotMeasureFrames() {
        let options = fixture.options
        options.tracesSampleRate = 0.0
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

    @available(*, deprecated, message: "Testing deprecated App Hang tracking option")
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
        let original = SentrySDK.internal.performance.framesTrackingHybridSDKMode
        SentrySDK.internal.performance.framesTrackingHybridSDKMode = true
        defer { SentrySDK.internal.performance.framesTrackingHybridSDKMode = original }

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

#if !targetEnvironment(macCatalyst)
    func testInit_whenTrackerCreatedBeforeOptionsWithUIUpdateLinkEnabled_shouldSwitchFrameSource() throws {
        guard #available(iOS 18.0, tvOS 18.0, visionOS 2.0, *) else {
            throw XCTSkip("UIUpdateLink is not available on this OS version")
        }

        // -- Arrange --
        // The tracker exists before the options are known, like with a launch profile.
        let tracker = fixture.framesTracker
        XCTAssertTrue(tracker.frameSourceForTesting is SentryDisplayLinkFrameSource)
        fixture.options.tracesSampleRate = 1
        fixture.options.experimental.enableUIUpdateLinkFramesTracking = true

        // -- Act --
        let sut = SentryFramesTrackingIntegration(with: fixture.options, dependencies: fixture.dependencies)

        // -- Assert --
        XCTAssertNotNil(sut)
        XCTAssertTrue(tracker.frameSourceForTesting is SentryUpdateLinkFrameSource)
        XCTAssertTrue(tracker.isRunning)
    }
#endif // !targetEnvironment(macCatalyst)

    func testInit_whenTrackerCreatedBeforeOptionsWithUIUpdateLinkDisabled_shouldKeepDisplayLink() throws {
        // -- Arrange --
        let tracker = fixture.framesTracker
        fixture.options.tracesSampleRate = 1

        // -- Act --
        let sut = SentryFramesTrackingIntegration(with: fixture.options, dependencies: fixture.dependencies)

        // -- Assert --
        XCTAssertNotNil(sut)
        XCTAssertTrue(tracker.frameSourceForTesting is SentryDisplayLinkFrameSource)
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
