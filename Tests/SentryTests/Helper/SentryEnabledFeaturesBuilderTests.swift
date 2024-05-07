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
        options.enablePerformanceV2 = true
        options.enableTimeToFullDisplayTracing = true
        options.swiftAsyncStacktraces = true
        options.enableMetrics = true

#if os(iOS) || os(tvOS)
        options.enableAppLaunchProfiling = true
#if canImport(UIKit) && !SENTRY_NO_UIKIT
        options.enablePreWarmedAppStartTracing = true
#endif // canImport(UIKit)
#endif // os(iOS) || os(tvOS)
        
        let features = SentryEnabledFeaturesBuilder.getEnabledFeatures(options: options)
        
        expect(features).to(contain([
            "captureFailedRequests",
            "performanceV2",
            "timeToFullDisplayTracing",
            "swiftAsyncStacktraces",
            "metrics"
        ]))
        
#if os(iOS) || os(tvOS)
        expect(features).to(contain(["appLaunchProfiling"]))
#if canImport(UIKit) && !SENTRY_NO_UIKIT
        expect(features).to(contain([
            "preWarmedAppStartTracing"
        ]))
#endif // canImport(UIKit)
#endif // os(iOS) || os(tvOS)
    }
}
