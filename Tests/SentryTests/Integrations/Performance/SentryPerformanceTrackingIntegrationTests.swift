import Nimble
import SentryTestUtils
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
        options.enableAutoPerformanceTracing = false
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
        let sut = SentryPerformanceTrackingIntegration()
        let result = sut.install(with: options)
        
        XCTAssertFalse(result)
        XCTAssertNil(Dynamic(sut).swizzling.asObject)
    }

    func testConfigure_waitForDisplay() {
        let sut = SentryPerformanceTrackingIntegration()

        let options = Options()
        options.tracesSampleRate = 0.1
        options.enableTimeToFullDisplayTracing = true
        sut.install(with: options)

        XCTAssertTrue(SentryUIViewControllerPerformanceTracker.shared.enableWaitForFullDisplay)
    }

    func testConfigure_dontWaitForDisplay() {
        let sut = SentryPerformanceTrackingIntegration()

        let options = Options()
        options.tracesSampleRate = 0.1
        options.enableTimeToFullDisplayTracing = false
        sut.install(with: options)

        XCTAssertFalse(SentryUIViewControllerPerformanceTracker.shared.enableWaitForFullDisplay)
    }
    
#endif
}
