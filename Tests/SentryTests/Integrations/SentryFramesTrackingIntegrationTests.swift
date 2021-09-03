import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class SentryFramesTrackingIntegrationTests: XCTestCase {

    private class Fixture {
        let options = Options()
        let displayLink = TestDiplayLinkWrapper()
        
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
    
    func testZeroTracesSampleRate_DoesNotMeasureFrames() {
        let options = fixture.options
        options.tracesSampleRate = 0.0
        sut.install(with: options)
        
        XCTAssertNil(Dynamic(sut).tracker.asObject)
    }
    
    func testAutoUIPerformanceTrackingDisabled_DoesNotMeasureFrames() {
        let options = fixture.options
        options.tracesSampleRate = 0.1
        options.enableAutoPerformanceTracking = false
        sut.install(with: options)
        
        XCTAssertNil(Dynamic(sut).tracker.asObject)
    }
    
    func testUninstall() {
        sut.install(with: fixture.options)
        
        SentryFramesTracker.sharedInstance().setDisplayLinkWrapper(fixture.displayLink)
        
        sut.uninstall()
        
        XCTAssertNil(fixture.displayLink.target)
        XCTAssertNil(fixture.displayLink.selector)
    }
}
#endif
