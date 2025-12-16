@_implementationOnly import _SentryPrivate
import Foundation

/// Protocol for batching metrics with scope-based attribute enrichment.
protocol MetricBatcherProtocol {
    /// Adds a metric to the batcher.
    /// - Parameters:
    ///   - metric: The metric to add
    ///   - scope: The scope to add the metric to
    func addMetric(_ metric: Metric, scope: Scope)
    
    /// Captures batched metrics synchronously and returns the duration.
    /// - Returns: The time taken to capture items in seconds
    ///
    /// - Note: This method blocks until all items are captured. The batcher's buffer is cleared after capture.
    ///         This is safe to call from any thread, but be aware that it uses dispatchSync internally,
    ///         so calling it from a context that holds locks or is on the batcher's queue itself could cause a deadlock.
    @discardableResult func captureMetrics() -> TimeInterval
}

protocol MetricBatcherOptionsProtocol {
    var enableMetrics: Bool { get }
    var beforeSendMetric: ((Metric) -> Metric?)? { get }
    var environment: String { get }
    var releaseName: String? { get }
    var cacheDirectoryPath: String { get }
}

struct MetricBatcher: MetricBatcherProtocol {
    private let isEnabled: Bool
    private let batcher: any BatcherProtocol<Metric, Scope>

    /// Initializes a new MetricBatcher.
    /// - Parameters:
    ///   - options: The Sentry configuration options
    ///   - flushTimeout: The timeout interval after which buffered metrics will be flushed
    ///   - maxMetricCount: Maximum number of metrics to batch before triggering an immediate flush.
    ///   - maxBufferSizeBytes: The maximum buffer size in bytes before triggering an immediate flush
    ///   - dateProvider: Instance used to determine current time
    ///   - dispatchQueue: A **serial** dispatch queue wrapper for thread-safe access to mutable state
    ///   - capturedDataCallback: The callback to handle captured metric batches. This callback is responsible
    ///                          for invoking client.captureMetricsData() with the batched data.
    ///
    /// - Important: The `dispatchQueue` parameter MUST be a serial queue to ensure thread safety.
    ///              Passing a concurrent queue will result in undefined behavior and potential data races.
    ///
    /// - Note: Metrics are flushed when either `maxMetricCount` or `maxBufferSizeBytes` limit is reached.
    init(
        options: MetricBatcherOptionsProtocol,
        flushTimeout: TimeInterval = 5,
        maxMetricCount: Int = 100, // Maximum 100 metrics per batch
        maxBufferSizeBytes: Int = 1_024 * 1_024, // 1MB buffer size
        dateProvider: SentryCurrentDateProvider,
        dispatchQueue: SentryDispatchQueueWrapper,
        capturedDataCallback: @escaping (_ data: Data, _ count: Int) -> Void
    ) {
        self.isEnabled = options.enableMetrics
        self.batcher = Batcher(
            config: .init(
                flushTimeout: flushTimeout,
                maxItemCount: maxMetricCount,
                maxBufferSizeBytes: maxBufferSizeBytes,
                beforeSendItem: options.beforeSendMetric,
                capturedDataCallback: capturedDataCallback
            ),
            metadata: .init(
                environment: options.environment,
                releaseName: options.releaseName,
                installationId: SentryInstallation.cachedId(withCacheDirectoryPath: options.cacheDirectoryPath)
            ),
            buffer: InMemoryBatchBuffer(),
            dateProvider: dateProvider,
            dispatchQueue: dispatchQueue
        )
    }
    
    func addMetric(_ metric: Metric, scope: Scope) {
        guard isEnabled else {
            return
        }
        batcher.add(metric, scope: scope)
    }

    @discardableResult
    func captureMetrics() -> TimeInterval {
        return batcher.capture()
    }
}

extension Options: MetricBatcherOptionsProtocol {}
