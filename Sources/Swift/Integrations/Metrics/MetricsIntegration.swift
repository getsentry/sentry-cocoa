@_implementationOnly import _SentryPrivate

protocol DispatchQueueWrapperProvider {
    var dispatchQueueWrapper: SentryDispatchQueueWrapper { get }
}

final class MetricsIntegration<Dependencies: DispatchQueueWrapperProvider>: NSObject, SwiftIntegration, SentryMetricBatcherDelegate {
    private let options: Options
    private var metricBatcher: SentryMetricBatcher!
    private let dispatchQueue: SentryDispatchQueueWrapper
    
    init?(with options: Options, dependencies: Dependencies) {
        guard options.enableMetrics else { return nil }

        self.options = options
        self.dispatchQueue = dependencies.dispatchQueueWrapper
        self.metricBatcher = SentryMetricBatcher(
            options: options,
            dispatchQueue: dispatchQueue
        )

        super.init()

        self.metricBatcher.delegate = self
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
            SentrySDKLog.debug("MetricsIntegration: No client available, dropping metrics")
            return
        }
        
        // Call the client's captureMetricsData method
        client.captureMetricsData(metricsData as Data, with: count)
    }
}
