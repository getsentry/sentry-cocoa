internal import _SentryPrivate

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

final class SentryFramesTrackingIntegration<Dependencies: FramesTrackingProvider>: NSObject, SwiftIntegration {
    let tracker: SentryFramesTracker

    init?(with options: Options, dependencies: Dependencies) {
        // Check hybrid SDK mode first - if enabled, always start frames tracking
        if !SentrySDKInternal.framesTrackingMeasurementHybridSDKMode {
            
            // Check if frames tracking should be enabled based on options
            let performanceDisabled = !options.enableAutoPerformanceTracing || !options.isTracingEnabled
            if performanceDisabled {
                SentrySDKLog.debug("Not going to enable \(Self.name) because enableAutoPerformanceTracing and isTracingEnabled are disabled.")
                return nil
            }
        }

        tracker = dependencies.framesTracker
        // A launch profile starts the tracker before the options are known, with the default
        // frame source.
        tracker.useFrameSource(dependencies.makeFrameSource(options: options))
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
