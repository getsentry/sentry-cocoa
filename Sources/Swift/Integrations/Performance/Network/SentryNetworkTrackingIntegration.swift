@_implementationOnly import _SentryPrivate

final class SentryNetworkTrackingIntegration<Dependencies: NetworkTrackerProvider>: NSObject, SwiftIntegration {
    
    private let networkTracker: SentryNetworkTracker
    
    init?(with options: Options, dependencies: Dependencies) {
        guard options.enableSwizzling else {
            SentrySDKLog.debug("Not going to enable \(Self.name) because enableSwizzling is disabled.")
            return nil
        }

        let shouldEnableNetworkTracking = Self.shouldBeEnabled(with: options)
        networkTracker = dependencies.networkTracker

        if shouldEnableNetworkTracking {
            networkTracker.enableNetworkTracking()
        }

        if options.enableNetworkBreadcrumbs {
            networkTracker.enableNetworkBreadcrumbs()
        }

        if options.enableCaptureFailedRequests {
            networkTracker.enableCaptureFailedRequests()
        }

        if options.enableGraphQLOperationTracking {
            networkTracker.enableGraphQLOperationTracking()
        }

        guard shouldEnableNetworkTracking || options.enableNetworkBreadcrumbs || options.enableCaptureFailedRequests else {
            return nil
        }

        super.init()

        SentrySwizzleWrapperHelper.swizzleURLSessionTask(networkTracker)
    }

    func uninstall() {
        networkTracker.disable()
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
