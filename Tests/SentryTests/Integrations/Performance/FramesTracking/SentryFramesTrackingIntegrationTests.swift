@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class SentryFramesTrackingIntegrationTests: XCTestCase {

    private class Fixture {
        let options = Options()
        let displayLink = TestDisplayLinkWrapper()
        
        init() {
            options.dsn = TestConstants.dsnAsString(username: "SentryFramesTrackingIntegrationTests")
        }
        
        var sut: SentryFramesTrackingIntegration {
            return SentryFramesTrackingIntegration()
        }
    }
    
    private let fixture = Fixture()
    private var sut: SentryFramesTrackingIntegration!
    
    override func setUp() {
        super.setUp()
        sut = fixture.sut
    }
    
    override func tearDown() {
        PrivateSentrySDKOnly.framesTrackingMeasurementHybridSDKMode = false
        clearTestState()
        super.tearDown()
    }
    
    func testTracesSampleRateSet_MeasuresFrames() {
        let options = fixture.options
        options.tracesSampleRate = 0.1
        sut.install(with: options)
        
        XCTAssertNotNil(Dynamic(sut).tracker.asObject)
    }
    
    func testTracesSamplerSet_MeasuresFrames() {
        let options = fixture.options
        options.tracesSampler = { _ in return 0 }
        sut.install(with: options)
        
        XCTAssertNotNil(Dynamic(sut).tracker.asObject)
    }

    func testAppHangEnabled_MeasuresFrames() {
        let options = fixture.options
        sut.install(with: options)

        XCTAssertNotNil(Dynamic(sut).tracker.asObject)
    }

    func testAppHangEnabled_ButIntervalZero_DoestNotMeasuresFrames() {
        let options = fixture.options
        options.appHangTimeoutInterval = 0.0
        options.enableWatchdogTerminationTracking = false
        sut.install(with: options)

        XCTAssertNil(Dynamic(sut).tracker.asObject)
    }

    func testZeroTracesSampleRate_DoesNotMeasureFrames() {
        let options = fixture.options
        options.tracesSampleRate = 0.0
        options.appHangTimeoutInterval = 0.0
        options.enableWatchdogTerminationTracking = false
        sut.install(with: options)
        
        XCTAssertNil(Dynamic(sut).tracker.asObject)
    }
    
    func testAutoPerformanceTrackingDisabled_DoesNotMeasureFrames() {
        let options = fixture.options
        options.tracesSampleRate = 0.1
        options.enableAutoPerformanceTracing = false
        options.enableAppHangTracking = false
        options.enableWatchdogTerminationTracking = false
        sut.install(with: options)
        
        XCTAssertNil(Dynamic(sut).tracker.asObject)
    }
    
    func test_HybridSDKEnables_MeasureFrames() {
        PrivateSentrySDKOnly.framesTrackingMeasurementHybridSDKMode = true
        
        let options = fixture.options
        options.enableAutoPerformanceTracing = false
        sut.install(with: options)
        
        XCTAssertNotNil(Dynamic(sut).tracker.asObject)
    }
    
    func testUninstall() {
        sut.install(with: fixture.options)
        
        SentryDependencyContainer.sharedInstance().framesTracker.setDisplayLinkWrapper(fixture.displayLink)
        
        sut.uninstall()
        
        XCTAssertNil(fixture.displayLink.target)
        XCTAssertNil(fixture.displayLink.selector)
    }
}
#endif
