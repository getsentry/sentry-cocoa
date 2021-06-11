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
        sut = fixture.sut
    }
    
    func testFrameRenderingEnabled_MeasuresFrames() {
        sut.install(with: fixture.options)
        
        XCTAssertNotNil(Dynamic(sut).tracker)
    }
    
    func testFrameRenderingDisabled_DoesNotMeasureFrames() {
        let options = fixture.options
        options.enableFrameRenderMeasuring = false
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
