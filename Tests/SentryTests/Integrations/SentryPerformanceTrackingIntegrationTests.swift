import XCTest

class SentryPerformanceTrackingIntegrationTests: XCTestCase {
    
    func testSwizzlingInitialized_WhenAPMandTracingEnabled() {
        let sut = SentryPerformanceTrackingIntegration()
        
        let options = Options()
        options.tracesSampleRate = 0.1
        sut.install(with: options)
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        XCTAssertNotNil(Dynamic(sut).swizzling.asObject)
#else
        XCTAssertNil(Dynamic(sut).swizzling.asObject)
#endif
    }
    
    func testSwizzlingNotInitialized_WhenTracingDisabled() {
        let sut = SentryPerformanceTrackingIntegration()
        
        sut.install(with: Options())
        
        XCTAssertNil(Dynamic(sut).swizzling.asObject)
    }
}
