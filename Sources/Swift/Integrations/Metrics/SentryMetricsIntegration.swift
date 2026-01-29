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

#if ((os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT) || os(macOS)
typealias SentryMetricsIntegrationDependencies = DateProviderProvider & DispatchQueueWrapperProvider & NotificationCenterProvider
#else
typealias SentryMetricsIntegrationDependencies = DateProviderProvider & DispatchQueueWrapperProvider
#endif

final class SentryMetricsIntegration<Dependencies: SentryMetricsIntegrationDependencies>: NSObject, SwiftIntegration, SentryMetricsIntegrationProtocol, FlushableIntegration {
    private let metricsBuffer: SentryMetricsTelemetryBuffer
    private let scopeApplier: SentryDefaultMetricScopeApplier
    #if ((os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT) || os(macOS)
    private let notificationCenter: SentryNSNotificationCenterWrapper
    #endif

    init?(with options: Options, dependencies: Dependencies) {
        guard options.experimental.enableMetrics else { return nil }

        let metadata = SentryDefaultScopeApplyingMetadata(
            environment: options.environment,
            releaseName: options.releaseName,
            cacheDirectoryPath: options.cacheDirectoryPath
        )
        self.scopeApplier = SentryDefaultMetricScopeApplier(metadata: metadata, sendDefaultPii: options.sendDefaultPii)

        self.metricsBuffer = DefaultSentryMetricsTelemetryBuffer(
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

        #if ((os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT) || os(macOS)
        self.notificationCenter = dependencies.notificationCenterWrapper
        #endif

        super.init()

        setupLifecycleObservers()
    }

    func uninstall() {
        // Flush any pending metrics before uninstalling.
        //
        // Note: This calls captureMetrics() synchronously, which uses dispatchSync internally.
        // This is safe because uninstall() is typically called from the main thread during
        // app lifecycle events, and the buffer's dispatch queue is a separate serial queue.
        metricsBuffer.captureMetrics()

        removeLifecycleObservers()
    }

    /// Ensures cleanup happens even if the integration is deallocated without explicit `uninstall()`.
    ///
    /// This defensive pattern guarantees that notification observers are removed, preventing crashes from dangling references.
    ///
    /// Note: We do NOT flush metrics in deinit because:
    /// - Flushing uses dispatchSync which can deadlock if deinit is called from the buffer's queue
    /// - uninstall() should be called explicitly before deallocation to ensure metrics are flushed
    /// - This prevents deadlocks during hub deallocation when integrations are released
    deinit {
        removeLifecycleObservers()
    }

    static var name: String {
        "SentryMetricsIntegration"
    }

    // MARK: - Public API for Metrics

    func addMetric(_ metric: SentryMetric, scope: Scope) {
        let enrichedMetric = scopeApplier.applyScope(scope, toMetric: metric)
        metricsBuffer.addMetric(enrichedMetric)
    }

    /// Captures batched metrics synchronously and returns the duration.
    /// - Returns: The time taken to capture metrics in seconds
    ///
    /// - Note: This method calls captureMetrics() on the internal buffer synchronously.
    ///         This is safe to call from any thread, but be aware that it uses dispatchSync internally.
    @discardableResult func captureMetrics() -> TimeInterval {
        return metricsBuffer.captureMetrics()
    }

    // MARK: - FlushableIntegration

    /// Flushes any buffered metrics synchronously.
    ///
    /// - Returns: The time taken to flush in seconds
    ///
    /// This method is called by SentryHub.flush() via respondsToSelector: check.
    /// We implement it directly in the class body (not in an extension) because
    /// extensions of generic classes cannot contain @objc members.
    /// The @objc attribute is required so Objective-C code can find this method
    /// via respondsToSelector: at runtime.
    @objc func flush() -> TimeInterval {
        return captureMetrics()
    }
    
    // MARK: - Lifecycle Handling
    
    private func setupLifecycleObservers() {
        #if ((os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT) || os(macOS)
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
        #endif
    }
    
    private func removeLifecycleObservers() {
        #if ((os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT) || os(macOS)
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
        #endif
    }
    
    // These methods are implemented in the main class body (not in an extension)
    // because extensions of generic classes cannot contain @objc members.
    #if ((os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT) || os(macOS)
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
