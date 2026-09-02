@_spi(Private) @testable import Sentry
import Foundation

public extension Options {
    
    func removeAllIntegrations() {
        enableAutoSessionTracking = false
        enableWatchdogTerminationTracking = false
        enableAutoPerformanceTracing = false
        enableCrashHandler = false
        swiftAsyncStacktraces = false
        #if !SDK_V10
        enableAppHangTracking = false
        #endif // !SDK_V10
        enableNetworkTracking = false
        enableNetworkBreadcrumbs = false
        enableCaptureFailedRequests = false
        enableAutoBreadcrumbTracking = false
        enableCoreDataTracing = false
        enableFileIOTracing = false
        #if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
        enableUserInteractionTracing = false
        attachViewHierarchy = false
        enableUIViewControllerTracing = false
        #endif
        enableMetricsValue = false
        beforeSendMetric = { metric in metric }
        #if canImport(MetricKit) && !os(tvOS)
        enableMetricKit = false
        #endif
    }

    static func noIntegrations() -> Options {
        let options = Options()
        options.removeAllIntegrations()
        return options
    }
}
