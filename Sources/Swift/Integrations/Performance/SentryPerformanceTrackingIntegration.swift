@_implementationOnly import _SentryPrivate

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

typealias PerformanceTrackingIntegrationProvider = UIViewControllerSwizzlingBuilder & UIViewControllerPerformanceTrackerProvider

final class SentryPerformanceTrackingIntegration<Dependencies: PerformanceTrackingIntegrationProvider>: NSObject, SwiftIntegration {
    private var swizzling: SentryUIViewControllerSwizzling

    init?(with options: Options, dependencies: Dependencies) {
        guard options.enableAutoPerformanceTracing else {
            SentrySDKLog.debug("Not going to enable \(Self.name) because enableAutoPerformanceTracing is disabled.")
            return nil
        }

        guard options.enableUIViewControllerTracing else {
            SentrySDKLog.debug("Not going to enable \(Self.name) because enableUIViewControllerTracing is disabled.")
            return nil
        }

        guard options.isTracingEnabled else {
            SentrySDKLog.debug("Not going to enable \(Self.name) because isTracingEnabled is disabled.")
            return nil
        }

        guard options.enableSwizzling else {
            SentrySDKLog.debug("Not going to enable \(Self.name) because enableSwizzling is disabled.")
            return nil
        }

        self.swizzling = dependencies.getUIViewControllerSwizzlingBuilder(options)
        
        super.init()

        swizzling.start()

        let performanceTracker = dependencies.uiViewControllerPerformanceTracker
        performanceTracker.alwaysWaitForFullDisplay = options.enableTimeToFullDisplayTracing
    }

    func uninstall() {
        swizzling.stop()
    }

    static var name: String {
        "SentryPerformanceTrackingIntegration"
    }
}

#endif
