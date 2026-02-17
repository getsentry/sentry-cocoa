// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate
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
        if options.experimental.enableMetrics {
            features.append("metrics")
        }
        if options.experimental.enableWatchdogTerminationRunLoopHangTracker {
            features.append("watchdog-termination.run-loop-hang-tracker.enabled")
        }

        return features
    }
    // swiftlint:enable cyclomatic_complexity function_body_length
}
// swiftlint:enable missing_docs
