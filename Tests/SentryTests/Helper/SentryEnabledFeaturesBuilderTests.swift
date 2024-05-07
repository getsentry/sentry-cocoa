import Nimble
@testable import Sentry
import XCTest

final class SentryEnabledFeaturesBuilderTests: XCTestCase {

    func testDefaultFeatures() throws {
        let features = SentryEnabledFeaturesBuilder.getEnabledFeatures(options: Options())
        
        expect(features) == ["captureFailedRequests"]
    }
    
    func testEnableAllFeatures() throws {
        
        let options = Options()
        options.enableAppLaunchProfiling = true
        options.enablePerformanceV2 = true
        options.enableTimeToFullDisplayTracing = true
        options.swiftAsyncStacktraces = true
        options.enableMetrics = true
#if SENTRY_UIKIT_AVAILABLE
        options.enablePreWarmedAppStartTracing = true
#endif
        
        let features = SentryEnabledFeaturesBuilder.getEnabledFeatures(options: options)
        
        expect(features).to(contain([
            "appLaunchProfiling",
            "captureFailedRequests",
            "performanceV2",
            "timeToFullDisplayTracing",
            "swiftAsyncStacktraces",
            "metrics"
        ]))
        
#if SENTRY_UIKIT_AVAILABLE
        expect(features).to(contain([
            "preWarmedAppStartTracing"
        ]))
#endif
    }
}
