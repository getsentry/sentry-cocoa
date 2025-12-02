final class MetricsIntegration<Dependencies>: NSObject, SwiftIntegration, SentryMetricBatcherDelegate {
    private let options: Options
    private let metricBatcher: SentryMetricBatcher
    private let dispatchQueue: SentryDispatchQueueWrapper
    
    init?(with options: Options, dependencies: Dependencies) {
        guard options.enableMetrics else { return nil }
        
        guard let dispatchQueueWrapper = dependencies.dispatchQueueWrapper else {
            SentrySDKLog.error("MetricsIntegration: dispatchQueueWrapper not available in dependencies")
            return nil
        }
        
        self.options = options
        self.dispatchQueue = dispatchQueueWrapper
        
        super.init()
        
        // Create the batcher with self as delegate after initialization
        self.metricBatcher = SentryMetricBatcher(
            options: options,
            dispatchQueue: dispatchQueue,
            delegate: self
        )
        
        SentrySDKLog.debug("MetricsIntegration initialized")
    }

    func uninstall() {
        // Flush any pending metrics before uninstalling
        metricBatcher.captureMetrics()
    }

    static var name: String {
        "SentryMetricsIntegration"
    }
    
    // MARK: - Public API for MetricsApi
    
    func addMetric(_ metric: SentryMetric, scope: Scope) {
        metricBatcher.addMetric(metric, scope: scope)
    }
    
    // MARK: - SentryMetricBatcherDelegate
    
    @objc(captureMetricsData:with:)
    func capture(metricsData: NSData, count: NSNumber) {
        // Get the client from the current hub
        let hub = SentrySDKInternal.currentHub()
        guard let client = hub.getClient() else {
            SentrySDKLog.warn("MetricsIntegration: No client available, dropping metrics")
            return
        }
        
        // Call the client's captureMetricsData method
        client.captureMetricsData(metricsData, with: count)
    }
}
