@_spi(Private) @testable import Sentry
import XCTest

final class SentryEnabledFeaturesBuilderTests: XCTestCase {

    func testDefaultFeatures() throws {
        // -- Arrange --
        let options = Options()

        // -- Act --
        let features = SentryEnabledFeaturesBuilder.getEnabledFeatures(options: options)

        // -- Assert --
#if SDK_V10
    #if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
        XCTAssertEqual(features, ["captureFailedRequests", "swiftAsyncStacktraces", "experimentalViewRenderer", "dataSwizzling", "metrics", "standaloneAppStartTracing", "watchdogTerminationsV2"])
    #elseif os(visionOS) && !SENTRY_NO_UI_FRAMEWORK
        XCTAssertEqual(features, ["captureFailedRequests", "swiftAsyncStacktraces", "dataSwizzling", "metrics", "standaloneAppStartTracing", "watchdogTerminationsV2"])
    #else
        XCTAssertEqual(features, ["captureFailedRequests", "swiftAsyncStacktraces", "dataSwizzling", "metrics"])
    #endif
#else
    #if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
        XCTAssertEqual(features, ["captureFailedRequests", "experimentalViewRenderer", "dataSwizzling", "metrics"])
    #else
        XCTAssertEqual(features, ["captureFailedRequests", "dataSwizzling", "metrics"])
    #endif
#endif
    }

    func testEnableAllFeatures() throws {
        // -- Arrange --
        let options = Options()
        options.enableTimeToFullDisplayTracing = true
        options.swiftAsyncStacktraces = true

        // -- Act --
        let features = SentryEnabledFeaturesBuilder.getEnabledFeatures(options: options)

        // -- Assert --
        XCTAssertTrue(features.contains("captureFailedRequests"))
        XCTAssertTrue(features.contains("timeToFullDisplayTracing"))
        XCTAssertTrue(features.contains("swiftAsyncStacktraces"))
    }

    func testEnableCaptureFailedRequests_isEnabled_shouldAddFeature() throws {
        // -- Arrange --
        let options = Options()
        options.enableCaptureFailedRequests = true

        // -- Act --
        let features = SentryEnabledFeaturesBuilder.getEnabledFeatures(options: options)

        // -- Assert --
        XCTAssertTrue(features.contains("captureFailedRequests"))
    }

    func testEnableCaptureFailedRequests_isDisabled_shouldNotAddFeature() throws {
        // -- Arrange --
        let options = Options()
        options.enableCaptureFailedRequests = false

        // -- Act --
        let features = SentryEnabledFeaturesBuilder.getEnabledFeatures(options: options)

        // -- Assert --
        XCTAssertFalse(features.contains("captureFailedRequests"))
    }

    func testEnableTimeToFullDisplayTracing_isDisabled_shouldNotAddFeature() throws {
        // -- Arrange --
        let options = Options()
        options.enableTimeToFullDisplayTracing = false

        // -- Act --
        let features = SentryEnabledFeaturesBuilder.getEnabledFeatures(options: options)

        // -- Assert --
        XCTAssertFalse(features.contains("timeToFullDisplayTracing"))
    }

    func testSwiftAsyncStacktraces_isDisabled_shouldNotAddFeature() throws {
        // -- Arrange --
        let options = Options()
        options.swiftAsyncStacktraces = false

        // -- Act --
        let features = SentryEnabledFeaturesBuilder.getEnabledFeatures(options: options)

        // -- Assert --
        XCTAssertFalse(features.contains("swiftAsyncStacktraces"))
    }

    func testEnablePersistingTracesWhenCrashing() {
        // -- Arrange --
        let options = Options()
        options.enablePersistingTracesWhenCrashing = true

        // -- Act --
        let features = SentryEnabledFeaturesBuilder.getEnabledFeatures(options: options)

        // -- Assert --
        XCTAssertTrue(features.contains("persistingTracesWhenCrashing"))
    }

    func testEnablePersistingTracesWhenCrashing_isDisabled_shouldNotAddFeature() {
        // -- Arrange --
        let options = Options()
        options.enablePersistingTracesWhenCrashing = false

        // -- Act --
        let features = SentryEnabledFeaturesBuilder.getEnabledFeatures(options: options)

        // -- Assert --
        XCTAssertFalse(features.contains("persistingTracesWhenCrashing"))
    }

    func testGetEnabledFeatures_optionsAreNil_shouldReturnEmptyArray() {
        // -- Act --
        let result = SentryEnabledFeaturesBuilder.getEnabledFeatures(options: nil)

        // -- Assert --
        XCTAssertEqual(result, [])
    }

    func testEnableViewRendererV2_isEnabled_shouldAddFeature() throws {
#if os(iOS)
        // -- Arrange --
        let options = Options()
        options.sessionReplay.enableViewRendererV2 = true

        // -- Act --
        let features = SentryEnabledFeaturesBuilder.getEnabledFeatures(options: options)

        // -- Assert --
        XCTAssertTrue(features.contains("experimentalViewRenderer"))
#else
        throw XCTSkip("Test not supported on this platform")
#endif
    }

    func testEnableViewRendererV2_isNotEnabled_shouldAddFeature() throws {
#if os(iOS)
        // -- Arrange --
        let options = Options()
        options.sessionReplay.enableViewRendererV2 = false

        // -- Act --
        let features = SentryEnabledFeaturesBuilder.getEnabledFeatures(options: options)

        // -- Assert --
        XCTAssertFalse(features.contains("experimentalViewRenderer"))
#else
        throw XCTSkip("Test not supported on this platform")
#endif
    }

    func testEnableFastViewRendering_isEnabled_shouldAddFeature() throws {
#if os(iOS)
        // -- Arrange --
        let options = Options()
        options.sessionReplay.enableFastViewRendering = true

        // -- Act --
        let features = SentryEnabledFeaturesBuilder.getEnabledFeatures(options: options)

        // -- Assert --
        XCTAssertTrue(features.contains("fastViewRendering"))
#else
        throw XCTSkip("Test not supported on this platform")
#endif
    }

    func testEnableFastViewRendering_isDisabled_shouldNotAddFeature() throws {
#if os(iOS)
        // -- Arrange --
        let options = Options()
        options.sessionReplay.enableFastViewRendering = false

        // -- Act --
        let features = SentryEnabledFeaturesBuilder.getEnabledFeatures(options: options)

        // -- Assert --
        XCTAssertFalse(features.contains("fastViewRendering"))
#else
        throw XCTSkip("Test not supported on this platform")
#endif
    }

    func testNetworkDetailHasUrls_withAllowUrls_shouldAddFeature() throws {
#if os(iOS)
        // -- Arrange --
        let options = Options()
        options.sessionReplay.networkDetailAllowUrls = ["https://api.example.com"]

        // -- Act --
        let features = SentryEnabledFeaturesBuilder.getEnabledFeatures(options: options)

        // -- Assert --
        XCTAssertTrue(features.contains("replayNetworkDetails"))
#else
        throw XCTSkip("Test not supported on this platform")
#endif
    }

    func testNetworkDetailHasUrls_withoutAllowUrls_shouldNotAddFeature() throws {
#if os(iOS)
        // -- Arrange --
        let options = Options()
        options.sessionReplay.networkDetailAllowUrls = []

        // -- Act --
        let features = SentryEnabledFeaturesBuilder.getEnabledFeatures(options: options)

        // -- Assert --
        XCTAssertFalse(features.contains("replayNetworkDetails"))
#else
        throw XCTSkip("Test not supported on this platform")
#endif
    }

    func testEnableDataSwizzling_isEnabled_shouldAddFeature() throws {
        // -- Arrange --
        let options = Options()
        options.enableDataSwizzling = true

        // -- Act --
        let features = SentryEnabledFeaturesBuilder.getEnabledFeatures(options: options)

        // -- Assert --
        XCTAssertTrue(features.contains("dataSwizzling"))
    }

    func testEnableDataSwizzling_isDisabled_shouldNotAddFeature() throws {
        // -- Arrange --
        let options = Options()
        options.enableDataSwizzling = false

        // -- Act --
        let features = SentryEnabledFeaturesBuilder.getEnabledFeatures(options: options)

        // -- Assert --
        XCTAssertFalse(features.contains("dataSwizzling"))
    }

    func testEnableFileManagerSwizzling_isEnabled_shouldAddFeature() throws {
        // -- Arrange --
        let options = Options()
        options.enableFileManagerSwizzling = true

        // -- Act --
        let features = SentryEnabledFeaturesBuilder.getEnabledFeatures(options: options)

        // -- Assert --
        XCTAssertTrue(features.contains("fileManagerSwizzling"))
    }

    func testEnableFileManagerSwizzling_isDisabled_shouldNotAddFeature() throws {
        // -- Arrange --
        let options = Options()
        options.enableFileManagerSwizzling = false

        // -- Act --
        let features = SentryEnabledFeaturesBuilder.getEnabledFeatures(options: options)

        // -- Assert --
        XCTAssertFalse(features.contains("fileManagerSwizzling"))
    }

    func testEnableUnhandledCPPExceptionsV2_shouldAddFeature() throws {
        // -- Arrange --
        let options = Options()
        options.experimental.enableUnhandledCPPExceptionsV2 = true

        // -- Act --
        let features = SentryEnabledFeaturesBuilder.getEnabledFeatures(options: options)

        // -- Assert --
        XCTAssertTrue(features.contains("unhandledCPPExceptionsV2"))
    }

    func testEnableUnhandledCPPExceptionsV2_isDisabled_shouldNotAddFeature() throws {
        // -- Arrange --
        let options = Options()
        options.experimental.enableUnhandledCPPExceptionsV2 = false

        // -- Act --
        let features = SentryEnabledFeaturesBuilder.getEnabledFeatures(options: options)

        // -- Assert --
        XCTAssertFalse(features.contains("unhandledCPPExceptionsV2"))
    }

    func testEnableMetrics_isEnabled_shouldAddFeature() throws {
        // -- Arrange --
        let options = Options()
        options.enableMetrics = true

        // -- Act --
        let features = SentryEnabledFeaturesBuilder.getEnabledFeatures(options: options)

        // -- Assert --
        XCTAssertTrue(features.contains("metrics"))
    }

    func testEnableMetrics_isDisabled_shouldNotAddFeature() throws {
        // -- Arrange --
        let options = Options()
        options.enableMetrics = false

        // -- Act --
        let features = SentryEnabledFeaturesBuilder.getEnabledFeatures(options: options)

        // -- Assert --
        XCTAssertFalse(features.contains("metrics"))
    }

    func testMaxFeatureFlags_isModified_shouldAddFeature() throws {
        // -- Arrange --
        let options = Options()
        options.maxFeatureFlags = 200

        // -- Act --
        let features = SentryEnabledFeaturesBuilder.getEnabledFeatures(options: options)

        // -- Assert --
        XCTAssertTrue(features.contains("maxFeatureFlags"))
    }

    func testMaxFeatureFlags_whenDefault_shouldNotAddFeature() throws {
        // -- Arrange --
        let options = Options()

        // -- Act --
        let features = SentryEnabledFeaturesBuilder.getEnabledFeatures(options: options)

        // -- Assert --
        XCTAssertFalse(features.contains("maxFeatureFlags"))
    }

    func testEnableStandaloneAppStartTracing_isEnabled_shouldAddFeature() throws {
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
        // -- Arrange --
        let options = Options()
        #if !SDK_V10
        options.enableStandaloneAppStartTracing = true
        #endif // !SDK_V10

        // -- Act --
        let features = SentryEnabledFeaturesBuilder.getEnabledFeatures(options: options)

        // -- Assert --
        XCTAssertTrue(features.contains("standaloneAppStartTracing"))
#else
        throw XCTSkip("Test not supported on this platform")
#endif
    }

    #if !SDK_V10
    func testEnableStandaloneAppStartTracing_isDisabled_shouldNotAddFeature() throws {
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
        // -- Arrange --
        let options = Options()
        options.enableStandaloneAppStartTracing = false

        // -- Act --
        let features = SentryEnabledFeaturesBuilder.getEnabledFeatures(options: options)

        // -- Assert --
        XCTAssertFalse(features.contains("standaloneAppStartTracing"))
#else
        throw XCTSkip("Test not supported on this platform")
#endif
    }

    func testEnableStandaloneAppStartTracing_whenDefault_shouldNotAddFeature() throws {
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
        // -- Arrange --
        let options = Options()

        // -- Act --
        let features = SentryEnabledFeaturesBuilder.getEnabledFeatures(options: options)

        // -- Assert --
        XCTAssertFalse(features.contains("standaloneAppStartTracing"))
#else
        throw XCTSkip("Test not supported on this platform")
#endif
    }
    #endif // !SDK_V10

    func testWatchdogTerminationsV2_shouldAddFeature() throws {
#if !SDK_V10 || ((os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK)
        // -- Arrange --
        let options = Options()
    #if !SDK_V10
        options.experimental.enableWatchdogTerminationsV2 = true
    #endif

        // -- Act --
        let features = SentryEnabledFeaturesBuilder.getEnabledFeatures(options: options)

        // -- Assert --
        XCTAssertTrue(features.contains("watchdogTerminationsV2"))
#else
        throw XCTSkip("Test not supported on this platform")
#endif
    }

#if !SDK_V10
    func testEnableWatchdogTerminationsV2_isDisabled_shouldNotAddFeature() throws {
        // -- Arrange --
        let options = Options()
        options.experimental.enableWatchdogTerminationsV2 = false

        // -- Act --
        let features = SentryEnabledFeaturesBuilder.getEnabledFeatures(options: options)

        // -- Assert --
        XCTAssertFalse(features.contains("watchdogTerminationsV2"))
    }
#endif

    func testEnableUIViewControllerInitSwizzling_isEnabled_shouldAddFeature() throws {
        // -- Arrange --
        let options = Options()

        options.experimental.enableUIViewControllerInitSwizzling = true

        // -- Act --
        let features = SentryEnabledFeaturesBuilder.getEnabledFeatures(options: options)

        // -- Assert --
        XCTAssertTrue(features.contains("uiViewControllerInitSwizzling"))
    }

    func testEnableUIViewControllerInitSwizzling_isDisabled_shouldNotAddFeature() throws {
        // -- Arrange --
        let options = Options()

        options.experimental.enableUIViewControllerInitSwizzling = false

        // -- Act --
        let features = SentryEnabledFeaturesBuilder.getEnabledFeatures(options: options)

        // -- Assert --
        XCTAssertFalse(features.contains("uiViewControllerInitSwizzling"))
    }

    func testEnableUIViewControllerInitSwizzling_whenDefault_shouldNotAddFeature() throws {
        // -- Arrange --
        let options = Options()

        // -- Act --
        let features = SentryEnabledFeaturesBuilder.getEnabledFeatures(options: options)

        // -- Assert --
        XCTAssertFalse(features.contains("uiViewControllerInitSwizzling"))
    }

    func testAttachViewHierarchy_isEnabled_shouldAddFeature() throws {
#if os(iOS)
        // -- Arrange --
        let options = Options()
        options.attachViewHierarchy = true

        // -- Act --
        let features = SentryEnabledFeaturesBuilder.getEnabledFeatures(options: options)

        // -- Assert --
        XCTAssertTrue(features.contains("viewHierarchy"))
#else
        throw XCTSkip("Test not supported on this platform")
#endif
    }

    func testAttachViewHierarchy_isDisabled_shouldNotAddFeature() throws {
#if os(iOS)
        // -- Arrange --
        let options = Options()
        options.attachViewHierarchy = false

        // -- Act --
        let features = SentryEnabledFeaturesBuilder.getEnabledFeatures(options: options)

        // -- Assert --
        XCTAssertFalse(features.contains("viewHierarchy"))
#else
        throw XCTSkip("Test not supported on this platform")
#endif
    }

    func testScreenshotFastViewRendering_isEnabled_shouldAddFeature() throws {
#if os(iOS)
        // -- Arrange --
        let options = Options()
        options.screenshot.enableFastViewRendering = true

        // -- Act --
        let features = SentryEnabledFeaturesBuilder.getEnabledFeatures(options: options)

        // -- Assert --
        XCTAssertTrue(features.contains("screenshotFastViewRendering"))
#else
        throw XCTSkip("Test not supported on this platform")
#endif
    }

    func testScreenshotFastViewRendering_isDisabled_shouldNotAddFeature() throws {
#if os(iOS)
        // -- Arrange --
        let options = Options()
        options.screenshot.enableFastViewRendering = false

        // -- Act --
        let features = SentryEnabledFeaturesBuilder.getEnabledFeatures(options: options)

        // -- Assert --
        XCTAssertFalse(features.contains("screenshotFastViewRendering"))
#else
        throw XCTSkip("Test not supported on this platform")
#endif
    }
}
