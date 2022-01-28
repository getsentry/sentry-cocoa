import XCTest

class SentryPerformanceTrackingIntegrationTests: XCTestCase {
    
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    func testSwizzlingInitialized_WhenAPMandTracingEnabled() {
        let sut = SentryPerformanceTrackingIntegration()
        
        let options = Options()
        options.tracesSampleRate = 0.1
        sut.install(with: options)

        XCTAssertNotNil(Dynamic(sut).swizzling.asObject)
    }
    
    func testSwizzlingNotInitialized_WhenTracingDisabled() {
        let sut = SentryPerformanceTrackingIntegration()
        
        sut.install(with: Options())
        
        XCTAssertNil(Dynamic(sut).swizzling.asObject)
    }
    
    func testSwizzlingNotInitialized_WhenAPMDisabled() {
        let sut = SentryPerformanceTrackingIntegration()
        
        let options = Options()
        options.tracesSampleRate = 0.1
        options.enableAutoPerformanceTracking = false
        sut.install(with: options)

        XCTAssertNil(Dynamic(sut).swizzling.asObject)
    }
    
    func testSwizzlingNotInitialized_WhenSwizzlingDisabled() {
        let sut = SentryPerformanceTrackingIntegration()
        
        let options = Options()
        options.tracesSampleRate = 0.1
        options.enableSwizzling = false
        sut.install(with: options)

        XCTAssertNil(Dynamic(sut).swizzling.asObject)
    }
    
    func test_AutoPerformanceDisabled_RemovesEnabledIntegration() {
        let options = Options()
        options.enableAutoPerformanceTracking = false
        
        let sut = SentryPerformanceTrackingIntegration()
        sut.install(with: options)
        
        let expexted = Options.defaultIntegrations().filter { !$0.contains("PerformanceTracking") }
        assertArrayEquals(expected: expexted, actual: Array(options.enabledIntegrations))
    }
    
#endif
}
