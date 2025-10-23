import Foundation
import Sentry

public extension Options {
    
    func removeAllIntegrations() {
        enableAutoSessionTracking = false
        enableWatchdogTerminationTracking = false
        enableAutoPerformanceTracing = false
        enableCrashHandler = false
        swiftAsyncStacktraces = false
        enableAppHangTracking = false
        enableNetworkTracking = false
        enableNetworkBreadcrumbs = false
        enableCaptureFailedRequests = false
        enableAutoBreadcrumbTracking = false
        #if (os(iOS) || os(tvOS) || (swift(>=5.9) && os(visionOS))) && !SENTRY_NO_UIKIT
        attachViewHierarchy = false
        enableUIViewControllerTracing = false
        #endif
    }

    static func noIntegrations() -> Options {
        let options = Options()
        options.removeAllIntegrations()
        return options
    }
}
