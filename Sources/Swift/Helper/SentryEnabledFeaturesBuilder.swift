import Foundation

@objcMembers class SentryEnabledFeaturesBuilder: NSObject {

    // swiftlint:disable cyclomatic_complexity
    static func getEnabledFeatures(options: Options?) -> [String] {
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
        if options.enableAppLaunchProfiling {
            features.append("appLaunchProfiling")
        }
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
        if options.enableAppHangTrackingV2 {
            features.append("appHangTrackingV2")
        }
#endif //os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        
        if options.enablePersistingTracesWhenCrashing {
            features.append("persistingTracesWhenCrashing")
        }

#if os(iOS) && !SENTRY_NO_UIKIT
        if options.sessionReplay.enableViewRendererV2 {
            features.append("experimentalViewRenderer")
        }
        if options.sessionReplay.enableFastViewRendering {
            features.append("fastViewRendering")
        }
#endif // #if os(iOS) && !SENTRY_NO_UIKIT
        return features
    }
    // swiftlint:enable cyclomatic_complexity
}
