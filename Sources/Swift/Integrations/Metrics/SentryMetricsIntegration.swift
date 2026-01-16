@_implementationOnly import _SentryPrivate

protocol SentryMetricsIntegrationProtocol {
    func addMetric(_ metric: SentryMetric, scope: Scope)
}

final class SentryMetricsIntegration<Dependencies: DateProviderProvider & DispatchQueueWrapperProvider>: NSObject, SwiftIntegration, SentryMetricsIntegrationProtocol {
    private let metricBatcher: SentryMetricsBatcherProtocol

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
    }

    func uninstall() {
        // Flush any pending metrics before uninstalling.
        //
        // Note: This calls captureMetrics() synchronously, which uses dispatchSync internally.
        // This is safe because uninstall() is typically called from the main thread during
        // app lifecycle events, and the batcher's dispatch queue is a separate serial queue.
        metricBatcher.captureMetrics()
    }

    static var name: String {
        "SentryMetricsIntegration"
    }
    
    // MARK: - Public API for Metrics

    func addMetric(_ metric: SentryMetric, scope: Scope) {
        metricBatcher.addMetric(metric, scope: scope)
    }
    
    /// Captures batched metrics synchronously and returns the duration.
    /// - Returns: The time taken to capture metrics in seconds
    ///
    /// - Note: This method calls captureMetrics() on the internal batcher synchronously.
    ///         This is safe to call from any thread, but be aware that it uses dispatchSync internally.
    @discardableResult func captureMetrics() -> TimeInterval {
        return metricBatcher.captureMetrics()
    }
}
