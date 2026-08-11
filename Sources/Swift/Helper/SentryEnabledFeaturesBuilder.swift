// swiftlint:disable missing_docs
internal import _SentryPrivate
import Foundation

@_spi(Private) @objc public final class SentryEnabledFeaturesBuilder: NSObject {

    // swiftlint:disable cyclomatic_complexity function_body_length
    @objc public static func getEnabledFeatures(options: Options?) -> [String] {
        guard let options = options else {
            return []
        }
        var features: [String] = []
        
        if options.enableCaptureFailedRequests {
            features.append("captureFailedRequests")
        }
        
        if options.enableTimeToFullDisplayTracing {
            features.append("timeToFullDisplayTracing")
        }
        
        if options.swiftAsyncStacktraces {
            features.append("swiftAsyncStacktraces")
        }
        
        if options.enablePersistingTracesWhenCrashing {
            features.append("persistingTracesWhenCrashing")
        }

#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
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
#endif // (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK

        if options.enableDataSwizzling {
            features.append("dataSwizzling")
        }
        if options.enableFileManagerSwizzling {
            features.append("fileManagerSwizzling")
        }
        if options.experimental.enableUnhandledCPPExceptionsV2 {
            features.append("unhandledCPPExceptionsV2")
        }
        if options.enableMetrics {
            features.append("metrics")
        }
        #if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
        #if SDK_V10
        features.append("standaloneAppStartTracing")
        #else
        if options.enableStandaloneAppStartTracing {
            features.append("standaloneAppStartTracing")
        }
        #endif // SDK_V10
        #endif // os(iOS) || os(tvOS) || os(visionOS)
        if options.experimental.enableWatchdogTerminationsV2 {
            features.append("watchdogTerminationsV2")
        }
        if options.experimental.enableUIViewControllerInitSwizzling {
            features.append("uiViewControllerInitSwizzling")
        }

#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
        if options.attachViewHierarchy {
            features.append("viewHierarchy")
        }
        if options.screenshot.enableFastViewRendering {
            features.append("screenshotFastViewRendering")
        }
#endif // (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK

        return features
    }
    // swiftlint:enable cyclomatic_complexity function_body_length
}
// swiftlint:enable missing_docs
