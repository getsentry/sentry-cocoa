@_implementationOnly import _SentryPrivate

protocol DispatchQueueWrapperProvider {
    var dateProvider: SentryCurrentDateProvider { get }
    var dispatchQueueWrapper: SentryDispatchQueueWrapper { get }
}

final class MetricsIntegration<Dependencies: DispatchQueueWrapperProvider>: NSObject, SwiftIntegration {
    private let options: Options
    private var metricBatcher: SentryMetricBatcher!

    init?(with options: Options, dependencies: Dependencies) {
        guard options.enableMetrics else { return nil }

        self.options = options
        self.metricBatcher = SentryMetricBatcher(
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
        super.init()
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
}
