@_implementationOnly import _SentryPrivate

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

final class SentryAppStartTrackingIntegration<Dependencies: SentryAppStartTrackerBuilder>: SwiftIntegration {
    let tracker: SentryAppStartTracker

    init?(with options: Options, dependencies: Dependencies) {
        // Check if the integration should be enabled based on hybrid SDK mode or tracing options
        if !PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode {
            // If hybrid SDK mode is not enabled, check if tracing is enabled
            guard options.enableAutoPerformanceTracing && options.isTracingEnabled else {
                SentrySDKLog.debug("Not going to enable \(Self.name) because enableAutoPerformanceTracing or isTracingEnabled is disabled.")
                return nil
            }
        }

        tracker = dependencies.getAppStartTracker(options)

        // Start tracking
        tracker.start()
    }

    func uninstall() {
        tracker.stop()
    }

    static var name: String {
        "SentryAppStartTrackingIntegration"
    }
}

#endif // (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
