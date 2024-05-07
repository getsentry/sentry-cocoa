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
        options.enablePreWarmedAppStartTracing = true
        options.swiftAsyncStacktraces = true
        options.enableMetrics = true
        
        let features = SentryEnabledFeaturesBuilder.getEnabledFeatures(options: options)
        
        expect(features).to(contain([
            "appLaunchProfiling",
            "captureFailedRequests",
            "performanceV2",
            "timeToFullDisplayTracing",
            "preWarmedAppStartTracing",
            "swiftAsyncStacktraces",
            "metrics"
        ]))
    }
}
