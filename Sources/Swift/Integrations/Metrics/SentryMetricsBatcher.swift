@_implementationOnly import _SentryPrivate
import Foundation

/// Protocol for batching metrics with scope-based attribute enrichment.
protocol SentryMetricsBatcherProtocol {
    /// Adds a metric to the batcher.
    /// - Parameters:
    ///   - metric: The metric to add
    ///   - scope: The scope to add the metric to
    func addMetric(_ metric: SentryMetric, scope: Scope)
    
    /// Captures batched metrics synchronously and returns the duration.
    /// - Returns: The time taken to capture items in seconds
    ///
    /// - Note: This method blocks until all items are captured. The batcher's buffer is cleared after capture.
    ///         This is safe to call from any thread, but be aware that it uses dispatchSync internally,
    ///         so calling it from a context that holds locks or is on the batcher's queue itself could cause a deadlock.
    @discardableResult func captureMetrics() -> TimeInterval
}

protocol SentryMetricsBatcherOptionsProtocol {
    var enableMetrics: Bool { get }
    var beforeSendMetric: ((SentryMetric) -> SentryMetric?)? { get }
    var environment: String { get }
    var releaseName: String? { get }
    var cacheDirectoryPath: String { get }
    var sendDefaultPii: Bool { get }
}

struct SentryMetricsBatcher: SentryMetricsBatcherProtocol {
    private let isEnabled: Bool
    private let batcher: any BatcherProtocol<SentryMetric, Scope>

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
        options: SentryMetricsBatcherOptionsProtocol,
        flushTimeout: TimeInterval = 5,
        maxMetricCount: Int = 100, // Maximum 100 metrics per batch
        maxBufferSizeBytes: Int = 2 * 1_024, // 2 KiB buffer size, see: https://develop.sentry.dev/sdk/data-model/envelopes/#size-limits
        dateProvider: SentryCurrentDateProvider,
        dispatchQueue: SentryDispatchQueueWrapper,
        capturedDataCallback: @escaping (_ data: Data, _ count: Int) -> Void
    ) {
        self.isEnabled = options.enableMetrics
        self.batcher = Batcher(
            config: .init(
                sendDefaultPii: options.sendDefaultPii,
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
    
    func addMetric(_ metric: SentryMetric, scope: Scope) {
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

extension Options: SentryMetricsBatcherOptionsProtocol {
    var enableMetrics: Bool {
        return experimental.enableMetrics
    }

    var beforeSendMetric: ((SentryMetric) -> SentryMetric?)? {
        return experimental.beforeSendMetric
    }
}
