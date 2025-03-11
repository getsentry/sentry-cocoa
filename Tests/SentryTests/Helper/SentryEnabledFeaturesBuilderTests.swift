@testable import Sentry
import XCTest

final class SentryEnabledFeaturesBuilderTests: XCTestCase {
    
    func testDefaultFeatures() throws {
        // -- Arrange --
        let options = Options()
        
        // -- Act --
        let features = SentryEnabledFeaturesBuilder.getEnabledFeatures(options: options)
        
        // -- Assert --
        XCTAssertEqual(features, ["captureFailedRequests"])
    }
    
    func testEnableAllFeatures() throws {
        // -- Arrange --
        let options = Options()
        options.enablePerformanceV2 = true
        options.enableTimeToFullDisplayTracing = true
        options.swiftAsyncStacktraces = true
        
#if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
        options.enableAppLaunchProfiling = true
#endif // os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
        
#if os(iOS) || os(tvOS)
#if canImport(UIKit) && !SENTRY_NO_UIKIT
        options.enablePreWarmedAppStartTracing = true
#endif // canImport(UIKit)
#endif // os(iOS) || os(tvOS)
        
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        options.enableAppHangTrackingV2 = true
#endif //os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        
        // -- Act --
        let features = SentryEnabledFeaturesBuilder.getEnabledFeatures(options: options)
        
        // -- Assert --
        XCTAssert(features.contains("captureFailedRequests"))
        XCTAssert(features.contains("performanceV2"))
        XCTAssert(features.contains("timeToFullDisplayTracing"))
        XCTAssert(features.contains("swiftAsyncStacktraces"))
        
#if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
        XCTAssert(features.contains("appLaunchProfiling"))
#endif // os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
        
#if os(iOS) || os(tvOS)
#if canImport(UIKit) && !SENTRY_NO_UIKIT
        XCTAssert(features.contains("preWarmedAppStartTracing"))
#endif // canImport(UIKit)
#endif // os(iOS) || os(tvOS)
        
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        XCTAssert(features.contains("appHangTrackingV2"))
#endif //os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    }
    
    func testEnablePersistingTracesWhenCrashing() {
        // -- Arrange --
        let options = Options()
        
        options.enablePersistingTracesWhenCrashing = true
        
        // -- Act --
        let features = SentryEnabledFeaturesBuilder.getEnabledFeatures(options: options)
        
        // -- Assert --
        XCTAssert(features.contains("persistingTracesWhenCrashing"))
    }
    
    func testEnableExperimentalViewRenderer_isEnabled_shouldAddFeature() throws {
        // -- Arrange --
        let options = Options()
        
        options.sessionReplay.enableExperimentalViewRenderer = true
        
        // -- Act --
        let features = SentryEnabledFeaturesBuilder.getEnabledFeatures(options: options)
        
        // -- Assert --
        XCTAssert(features.contains("experimentalViewRenderer"))
    }
    
    func testEnableFastViewRendering_isEnabled_shouldAddFeature() throws {
        // -- Arrange --
        let options = Options()
        
        options.sessionReplay.enableFastViewRendering = true
        
        // -- Act --
        let features = SentryEnabledFeaturesBuilder.getEnabledFeatures(options: options)
        
        // -- Assert --
        XCTAssert(features.contains("fastViewRendering"))
    }
}
