@_implementationOnly import _SentryPrivate
import Foundation

final class SentryEnabledFeaturesBuilder: NSObject {

    // swiftlint:disable cyclomatic_complexity function_body_length
    static func getEnabledFeatures(options: Options?) -> [String] {
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

#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
        if options.enableViewRendererV2() {
            // We keep the old name for backwards compatibility of the telemetry data.
            features.append("experimentalViewRenderer")
        }
        if options.enableFastViewRendering() {
            features.append("fastViewRendering")
        }
#endif // (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT

        if options.enableDataSwizzling {
            features.append("dataSwizzling")
        }
        if options.enableFileManagerSwizzling {
            features.append("fileManagerSwizzling")
        }
        if options.experimental.enableUnhandledCPPExceptionsV2 {
            features.append("unhandledCPPExceptionsV2")
        }

        return features
    }
    // swiftlint:enable cyclomatic_complexity function_body_length
}
