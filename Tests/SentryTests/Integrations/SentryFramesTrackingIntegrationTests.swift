import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class SentryFramesTrackingIntegrationTests: XCTestCase {

    private class Fixture {
        let options = Options()
        let displayLink = TestDiplayLinkWrapper()
        
        init() {
            options.dsn = TestConstants.dsnAsString(username: "SentryFramesTrackingIntegrationTests")
        }
    }
    
    private var fixture: Fixture!
    
    override func setUp() {
        fixture = Fixture()
    }
    
    func testFrameRenderingEnabled_MeasuresFrames() {
        let sut = SentryFramesTrackingIntegration()
        sut.install(with: fixture.options)
        
        XCTAssertNotNil(Dynamic(sut).tracker)
    }
    
    func testFrameRenderingDisabled_DoesNotMeasureFrames() {
        let sut = SentryFramesTrackingIntegration()
        let options = fixture.options
        options.enableRenderFrameMeasuring = false
        sut.install(with: options)
        
        XCTAssertNil(Dynamic(sut).tracker.asObject)
    }
    
    func testUninstall() {
        let sut = SentryFramesTrackingIntegration()
        sut.install(with: fixture.options)
        
        SentryFramesTracker.sharedInstance().setDisplayLinkWrapper(fixture.displayLink)
        
        sut.uninstall()
        
        XCTAssertNil(fixture.displayLink.target)
        XCTAssertNil(fixture.displayLink.selector)
    }
}
#endif
