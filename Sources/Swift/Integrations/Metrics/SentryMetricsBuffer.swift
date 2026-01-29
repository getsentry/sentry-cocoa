@_implementationOnly import _SentryPrivate
import Foundation

protocol SentryMetricsTelemetryBuffer {
    func addMetric(_ metric: SentryMetric)
    @discardableResult func captureMetrics() -> TimeInterval
}

protocol SentryMetricsTelemetryBufferOptions {
    var enableMetrics: Bool { get }
    var beforeSendMetric: ((SentryMetric) -> SentryMetric?)? { get }
    var environment: String { get }
    var releaseName: String? { get }
    var cacheDirectoryPath: String { get }
    var sendDefaultPii: Bool { get }
}

/// DefaultSentryMetricsTelemetryBuffer is responsible for buffering metrics.
struct DefaultSentryMetricsTelemetryBuffer: SentryMetricsTelemetryBuffer {
    private let isEnabled: Bool
    private let buffer: any TelemetryBuffer<SentryMetric>

    /// Initializes a new MetricsBuffer.
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
        options: SentryMetricsTelemetryBufferOptions,
        flushTimeout: TimeInterval = 5,
        maxMetricCount: Int = 100, // Maximum 100 metrics per batch
        maxBufferSizeBytes: Int = 1_024 * 1_024, // 1MB buffer size for trace metrics
        dateProvider: SentryCurrentDateProvider,
        dispatchQueue: SentryDispatchQueueWrapper,
        capturedDataCallback: @escaping (_ data: Data, _ count: Int) -> Void
    ) {
        self.isEnabled = options.enableMetrics
        self.buffer = DefaultTelemetryBuffer(
            config: .init(
                sendDefaultPii: options.sendDefaultPii,
                flushTimeout: flushTimeout,
                maxItemCount: maxMetricCount,
                maxBufferSizeBytes: maxBufferSizeBytes,
                beforeSendItem: options.beforeSendMetric,
                capturedDataCallback: capturedDataCallback
            ),
            buffer: InMemoryInternalTelemetryBuffer(),
            dateProvider: dateProvider,
            dispatchQueue: dispatchQueue
        )
    }
    
    /// Adds a metric to the buffer.
    /// - Parameters:
    ///   - metric: The metric to add (should already have scope enrichment applied)
    func addMetric(_ metric: SentryMetric) {
        guard isEnabled else {
            return
        }
        buffer.add(metric)
    }

    /// Captures buffered metrics synchronously and returns the duration.
    /// - Returns: The time taken to capture items in seconds
    ///
    /// - Note: This method blocks until all items are captured. The buffer is cleared after capture.
    ///         This is safe to call from any thread, but be aware that it uses dispatchSync internally,
    ///         so calling it from a context that holds locks or is on the buffer's queue itself could cause a deadlock.
    @discardableResult func captureMetrics() -> TimeInterval {
        return buffer.capture()
    }
}

extension Options: SentryMetricsTelemetryBufferOptions {
    // As soon as the feature is not experimental anymore, we can remove these two bridging methods.
        
    var enableMetrics: Bool {
        return experimental.enableMetrics
    }

    var beforeSendMetric: ((SentryMetric) -> SentryMetric?)? {
        return experimental.beforeSendMetric
    }
}
