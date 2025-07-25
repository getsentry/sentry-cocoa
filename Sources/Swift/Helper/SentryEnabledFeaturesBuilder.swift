@_implementationOnly import _SentryPrivate
import Foundation

@objcMembers @_spi(Private) public class SentryEnabledFeaturesBuilder: NSObject {

    // swiftlint:disable cyclomatic_complexity function_body_length
    @available(*, deprecated, message: "This is only marked as deprecated because enableAppLaunchProfiling is marked as deprecated. Once that is removed this can be removed.")
    public static func getEnabledFeatures(options: Options?) -> [String] {
        guard let options = options else {
            return []
        }
        var features: [String] = []
        
        if options.enableCaptureFailedRequests {
            features.append("captureFailedRequests")
        }
        
        if options.enablePerformanceV2 {
            features.append("performanceV2")
        }
        
        if options.enableTimeToFullDisplayTracing {
            features.append("timeToFullDisplayTracing")
        }

#if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
        #if !SDK_V9
        if options.enableAppLaunchProfiling {
            features.append("appLaunchProfiling")
        }
        #endif // !SDK_V9
#endif // os(iOS) || os(macOS) || targetEnvironment(macCatalyst)

#if os(iOS) || os(tvOS)
#if canImport(UIKit) && !SENTRY_NO_UIKIT
        if options.enablePreWarmedAppStartTracing {
            features.append("preWarmedAppStartTracing")
        }
#endif // canImport(UIKit)
#endif // os(iOS) || os(tvOS)
        
        if options.swiftAsyncStacktraces {
            features.append("swiftAsyncStacktraces")
        }

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        #if !SDK_V9
        if options.enableAppHangTrackingV2 {
            features.append("appHangTrackingV2")
        }
        #endif // !SDK_V9
#endif //os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        
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

        if options.experimental.enableDataSwizzling {
            features.append("dataSwizzling")
        }
        if options.experimental.enableFileManagerSwizzling {
            features.append("fileManagerSwizzling")
        }
        if options.experimental.enableUnhandledCPPExceptionsV2 {
            features.append("unhandledCPPExceptionsV2")
        }

        return features
    }
    // swiftlint:enable cyclomatic_complexity function_body_length
}
