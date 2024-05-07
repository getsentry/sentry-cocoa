import Foundation

@objcMembers class SentryEnabledFeaturesBuilder: NSObject {
    
    static func getEnabledFeatures(options: Options) -> [String] {
        
        var features: [String] = []
        
        if options.enableAppLaunchProfiling {
            features.append("appLaunchProfiling")
        }
        
        if options.enableCaptureFailedRequests {
            features.append("captureFailedRequests")
        }
        
        if options.enablePerformanceV2 {
            features.append("performanceV2")
        }
        
        if options.enableTimeToFullDisplayTracing {
            features.append("timeToFullDisplayTracing")
        }
        
#if SENTRY_UIKIT_AVAILABLE
        if options.enablePreWarmedAppStartTracing {
            features.append("preWarmedAppStartTracing")
        }
#endif
        
        if options.swiftAsyncStacktraces {
            features.append("swiftAsyncStacktraces")
        }
        
        if options.enableMetrics {
            features.append("metrics")
        }
        
        return features
    }
}
