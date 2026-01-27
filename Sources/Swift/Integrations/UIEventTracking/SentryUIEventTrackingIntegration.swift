@_implementationOnly import _SentryPrivate

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT

typealias UIEventTrackingIntegrationProvider = SentryEventTrackerBuilder

final class SentryUIEventTrackingIntegration<Dependencies: UIEventTrackingIntegrationProvider>: NSObject, SwiftIntegration {
    private let uiEventTracker: SentryUIEventTracker

    init?(with options: Options, dependencies: Dependencies) {
        guard options.enableAutoPerformanceTracing else {
            SentrySDKLog.debug("Not going to enable \(Self.name) because enableAutoPerformanceTracing is disabled.")
            return nil
        }

        guard options.enableSwizzling else {
            SentrySDKLog.debug("Not going to enable \(Self.name) because enableSwizzling is disabled.")
            return nil
        }

        guard options.isTracingEnabled else {
            SentrySDKLog.debug("Not going to enable \(Self.name) because tracing is not enabled.")
            return nil
        }

        guard options.enableUserInteractionTracing else {
            SentrySDKLog.debug("Not going to enable \(Self.name) because enableUserInteractionTracing is disabled.")
            return nil
        }

        self.uiEventTracker = dependencies.getUIEventTracker(options)

        super.init()

        uiEventTracker.start()
    }

    func uninstall() {
        uiEventTracker.stop()
    }

    static var name: String {
        "SentryUIEventTrackingIntegration"
    }
}

#endif // SENTRY_HAS_UIKIT
