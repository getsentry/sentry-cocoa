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
#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)
        options.enablePreWarmedAppStartTracing = true
#endif // os(iOS) || os(tvOS)
#endif // canImport(UIKit)
        
        let features = SentryEnabledFeaturesBuilder.getEnabledFeatures(options: options)
        
        expect(features).to(contain([
            "appLaunchProfiling",
            "captureFailedRequests",
            "performanceV2",
            "timeToFullDisplayTracing",
            "swiftAsyncStacktraces",
            "metrics"
        ]))
        
#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)
        expect(features).to(contain([
            "preWarmedAppStartTracing"
        ]))
#endif // os(iOS) || os(tvOS)
#endif // canImport(UIKit)
    }
}
