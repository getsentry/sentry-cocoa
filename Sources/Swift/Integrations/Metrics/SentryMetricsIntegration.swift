@_implementationOnly import _SentryPrivate

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT
import UIKit
private typealias CrossPlatformApplication = UIApplication
#elseif os(macOS)
import AppKit
private typealias CrossPlatformApplication = NSApplication
#endif

protocol SentryMetricsIntegrationProtocol {
    func addMetric(_ metric: SentryMetric, scope: Scope)
}

typealias SentryMetricsIntegrationDependencies = DateProviderProvider & DispatchQueueWrapperProvider & NotificationCenterProvider

final class SentryMetricsIntegration<Dependencies: SentryMetricsIntegrationDependencies>: NSObject, SwiftIntegration, SentryMetricsIntegrationProtocol {
    private let metricBatcher: SentryMetricsBatcherProtocol
    private let notificationCenter: SentryNSNotificationCenterWrapper

    init?(with options: Options, dependencies: Dependencies) {
        guard options.experimental.enableMetrics else { return nil }

        self.metricBatcher = SentryMetricsBatcher(
            options: options,
            dateProvider: dependencies.dateProvider,
            dispatchQueue: dependencies.dispatchQueueWrapper,
            capturedDataCallback: { data, count in
                let hub = SentrySDKInternal.currentHub()
                guard let client = hub.getClient() else {
                    SentrySDKLog.debug("MetricsIntegration: No client available, dropping metrics")
                    return
                }
                client.captureMetricsData(data, with: NSNumber(value: count))
            }
        )
        
        self.notificationCenter = dependencies.notificationCenterWrapper
        super.init()
        
        #if ((os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT) || os(macOS)
        setupLifecycleObservers()
        #endif
    }

    func uninstall() {
        // Flush any pending metrics before uninstalling.
        //
        // Note: This calls captureMetrics() synchronously, which uses dispatchSync internally.
        // This is safe because uninstall() is typically called from the main thread during
        // app lifecycle events, and the batcher's dispatch queue is a separate serial queue.
        metricBatcher.captureMetrics()
        
        #if ((os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT) || os(macOS)
        removeLifecycleObservers()
        #endif
    }

    static var name: String {
        "SentryMetricsIntegration"
    }
    
    // MARK: - Public API for SentryMetricsApi

    func addMetric(_ metric: SentryMetric, scope: Scope) {
        metricBatcher.addMetric(metric, scope: scope)
    }
    
    /// Captures batched metrics synchronously and returns the duration.
    /// - Returns: The time taken to capture metrics in seconds
    ///
    /// - Note: This method calls captureMetrics() on the internal batcher synchronously.
    ///         This is safe to call from any thread, but be aware that it uses dispatchSync internally.
    @discardableResult
    @objc func captureMetrics() -> TimeInterval {
        return metricBatcher.captureMetrics()
    }
    
    // MARK: - FlushableIntegration
    
    /// Flushes any buffered metrics synchronously.
    /// - Returns: The time taken to flush in seconds
    ///
    /// This method is called by SentryHub.flush() via respondsToSelector: check.
    /// We implement it directly in the class body (not in an extension) because
    /// extensions of generic classes cannot contain @objc members.
    @discardableResult
    @objc func flush() -> TimeInterval {
        return captureMetrics()
    }
    
    // MARK: - Lifecycle Handling
    
    #if ((os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT) || os(macOS)
    private func setupLifecycleObservers() {
        notificationCenter.addObserver(
            self,
            selector: #selector(willResignActive),
            name: CrossPlatformApplication.willResignActiveNotification,
            object: nil
        )
        
        notificationCenter.addObserver(
            self,
            selector: #selector(willTerminate),
            name: CrossPlatformApplication.willTerminateNotification,
            object: nil
        )
    }
    
    private func removeLifecycleObservers() {
        notificationCenter.removeObserver(
            self,
            name: CrossPlatformApplication.willResignActiveNotification,
            object: nil
        )
        
        notificationCenter.removeObserver(
            self,
            name: CrossPlatformApplication.willTerminateNotification,
            object: nil
        )
    }
    
    // These methods are implemented in the main class body (not in an extension)
    // because extensions of generic classes cannot contain @objc members.
    @objc private func willResignActive() {
        // Flush metrics directly via the integration's flush method
        _ = flush() // Use discardable result
    }
    
    @objc private func willTerminate() {
        // Flush metrics directly via the integration's flush method
        _ = flush() // Use discardable result
    }
    #endif
}
