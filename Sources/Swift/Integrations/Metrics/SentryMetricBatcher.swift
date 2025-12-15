@_implementationOnly import _SentryPrivate
import Foundation

class SentryMetricBatcher {
    private let isEnabled: Bool
    private let batcher: any BatcherProtocol<SentryMetric, Scope>

    /// Initializes a new SentryMetricBatcher.
    /// - Parameters:
    ///   - options: The Sentry configuration options
    ///   - flushTimeout: The timeout interval after which buffered metrics will be flushed
    ///   - maxMetricCount: Maximum number of metrics to batch before triggering an immediate flush.
    ///   - maxBufferSizeBytes: The maximum buffer size in bytes before triggering an immediate flush
    ///   - dateProvider: Instance used to determine current time
    ///   - dispatchQueue: A **serial** dispatch queue wrapper for thread-safe access to mutable state
    ///   - delegate: The delegate to handle captured metric batches
    ///
    /// - Important: The `dispatchQueue` parameter MUST be a serial queue to ensure thread safety.
    ///              Passing a concurrent queue will result in undefined behavior and potential data races.
    ///
    /// - Note: Metrics are flushed when either `maxMetricCount` or `maxBufferSizeBytes` limit is reached.
    init(
        options: Options,
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
    
    func addMetric(_ metric: SentryMetric, scope: Scope) {
        guard isEnabled else {
            return
        }
        batcher.add(metric, scope: scope)
    }

    /// Captures batched metrics sync and returns the duration.
    @discardableResult
    func captureMetrics() -> TimeInterval {
        return batcher.capture()
    }
}

extension SentryMetric: BatcherItem {}
