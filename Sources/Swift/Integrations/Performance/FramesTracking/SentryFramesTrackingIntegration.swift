@_implementationOnly import _SentryPrivate

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT

final class SentryFramesTrackingIntegration<Dependencies: FramesTrackingProvider>: NSObject, SwiftIntegration {
    let tracker: SentryFramesTracker

    init?(with options: Options, dependencies: Dependencies) {
        // Check hybrid SDK mode first - if enabled, always start frames tracking
        if !PrivateSentrySDKOnly.framesTrackingMeasurementHybridSDKMode {
            
            // Check if frames tracking should be enabled based on options
            let performanceDisabled = !options.enableAutoPerformanceTracing || !options.isTracingEnabled
            let appHangsDisabled = options.isAppHangTrackingDisabled()
            let watchdogDisabled = !options.enableWatchdogTerminationTracking

            // The watchdog tracker uses the frames tracker, so frame tracking
            // must be enabled if watchdog tracking is enabled.
            if performanceDisabled && appHangsDisabled && watchdogDisabled {
                if appHangsDisabled {
                    SentrySDKLog.debug("Not going to enable \(Self.name) because enableAppHangTracking is disabled or the appHangTimeoutInterval is 0.")
                }

                if performanceDisabled {
                    SentrySDKLog.debug("Not going to enable \(Self.name) because enableAutoPerformanceTracing and isTracingEnabled are disabled.")
                }

                if watchdogDisabled {
                    SentrySDKLog.debug("Not going to enable \(Self.name) because enableWatchdogTerminationTracking is disabled.")
                }

                return nil
            }
        }

        tracker = dependencies.framesTracker
        tracker.start()
    }

    func uninstall() {
        tracker.stop()
    }

    static var name: String {
        "SentryFramesTrackingIntegration"
    }
}

#endif
