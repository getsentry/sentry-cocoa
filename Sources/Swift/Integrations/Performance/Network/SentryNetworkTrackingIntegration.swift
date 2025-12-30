@_implementationOnly import _SentryPrivate

final class SentryNetworkTrackingIntegration<Dependencies>: NSObject, SwiftIntegration {
    
    init?(with options: Options, dependencies: Dependencies) {
        guard options.enableSwizzling else {
            SentrySDKLog.debug("Not going to enable \(Self.name) because enableSwizzling is disabled.")
            return nil
        }

        let shouldEnableNetworkTracking = Self.shouldBeEnabled(with: options)

        if shouldEnableNetworkTracking {
            SentryNetworkTracker.sharedInstance.enableNetworkTracking()
        }

        if options.enableNetworkBreadcrumbs {
            SentryNetworkTracker.sharedInstance.enableNetworkBreadcrumbs()
        }

        if options.enableCaptureFailedRequests {
            SentryNetworkTracker.sharedInstance.enableCaptureFailedRequests()
        }

        if options.enableGraphQLOperationTracking {
            SentryNetworkTracker.sharedInstance.enableGraphQLOperationTracking()
        }

        guard shouldEnableNetworkTracking || options.enableNetworkBreadcrumbs || options.enableCaptureFailedRequests else {
            return nil
        }

        super.init()

        SentrySwizzleWrapperHelper.swizzleURLSessionTask()
    }

    func uninstall() {
        SentryNetworkTracker.sharedInstance.disable()
    }

    static var name: String {
        "SentryNetworkTrackingIntegration"
    }

    private static func shouldBeEnabled(with options: Options) -> Bool {
        guard options.isTracingEnabled else {
            SentrySDKLog.debug("Not going to enable \(name) because isTracingEnabled is disabled.")
            return false
        }

        guard options.enableAutoPerformanceTracing else {
            SentrySDKLog.debug("Not going to enable \(name) because enableAutoPerformanceTracing is disabled.")
            return false
        }

        guard options.enableNetworkTracking else {
            SentrySDKLog.debug("Not going to enable \(name) because enableNetworkTracking is disabled.")
            return false
        }

        return true
    }
}
