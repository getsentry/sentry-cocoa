// swiftlint:disable missing_docs
internal import _SentryPrivate
import Foundation

@_spi(Private) @objc public final class SentryEnabledFeaturesBuilder: NSObject {

    // swiftlint:disable cyclomatic_complexity function_body_length
    @objc public static func getEnabledFeatures(options: Options?) -> [String] {
        // When changing the list of tracked features, make sure to update the corresponding dashboard too.
        // https://sentryio.cloud.looker.com/dashboards/1820
        guard let options = options else {
            return []
        }
        var features: [String] = []

        // -- Feature: Errors --
        if options.enableUnhandledCPPExceptionsV2 {
            features.append("unhandledCPPExceptionsV2")
        }
        if options.swiftAsyncStacktraces {
            features.append("swiftAsyncStacktraces")
        }
        if options.enablePersistingTracesWhenCrashing {
            features.append("persistingTracesWhenCrashing")
        }
        if options.maxFeatureFlags != defaultMaxScopeFeatureFlags {
            // Only tracking if modified from the default
            features.append("maxFeatureFlags")
        }

        // -- Feature: Mobile Vitals --
        #if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
        #if SDK_V10
        features.append("standaloneAppStartTracing")
        #else
        if options.enableStandaloneAppStartTracing {
            features.append("standaloneAppStartTracing")
        }
        #endif // SDK_V10
        #endif // os(iOS) || os(tvOS) || os(visionOS)
        if options.enableTimeToFullDisplayTracing {
            features.append("timeToFullDisplayTracing")
        }

        // -- Feature: File I/O --
        if options.enableDataSwizzling {
            features.append("dataSwizzling")
        }
        if options.enableFileManagerSwizzling {
            features.append("fileManagerSwizzling")
        }

        // -- Feature: Network I/O --
        if options.enableCaptureFailedRequests {
            features.append("captureFailedRequests")
        }
        if options.enableGraphQLOperationTracking {
            features.append("graphQLOperationTracking")
        }

        // -- Feature: Metrics --
        #if SDK_V10
        features.append("metrics")
        #else
        if options.enableMetrics {
            features.append("metrics")
        }
        #endif // SDK_V10

        // -- Feature: Screenshots --
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
        if options.screenshot.enableFastViewRendering {
            features.append("screenshotFastViewRendering")
        }
#endif // (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

        // -- Feature: Session Replay --
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
        if options.sessionReplay.enableViewRendererV2 {
            // We keep the old name for backwards compatibility of the telemetry data.
            features.append("experimentalViewRenderer")
        }
        if options.sessionReplay.enableFastViewRendering {
            features.append("fastViewRendering")
        }
        if options.sessionReplay.networkDetailHasUrls {
            features.append("replayNetworkDetails")
        }
#endif // (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

        // -- Feature: View Hierarchy --
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
        if options.attachViewHierarchy {
            features.append("viewHierarchy")
        }
#endif

        // --- Experimental Features ---
        #if !SDK_V10
        if options.experimental.enableWatchdogTerminationsV2 {
            features.append("watchdogTerminationsV2")
        }
        #elseif (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
        features.append("watchdogTerminationsV2")
        #endif

        if options.experimental.enableNewURLLoaderSwizzling {
            features.append("newURLLoaderSwizzling")
        }
        if options.experimental.enableUIViewControllerInitSwizzling {
            features.append("uiViewControllerInitSwizzling")
        }

        return features
    }
    // swiftlint:enable cyclomatic_complexity function_body_length
}
// swiftlint:enable missing_docs
