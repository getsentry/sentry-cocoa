@_implementationOnly import _SentryPrivate
import Foundation

protocol SentryMetricsTelemetryBuffer {
    func addMetric(_ metric: SentryMetric)
    @discardableResult func captureMetrics() -> TimeInterval
}

/// DefaultSentryMetricsTelemetryBuffer is responsible for buffering metrics.
struct DefaultSentryMetricsTelemetryBuffer: SentryMetricsTelemetryBuffer {
    private let buffer: any TelemetryBuffer<SentryMetric>

    /// Initializes a new MetricsBuffer.
    /// - Parameters:
    ///   - flushTimeout: The timeout interval after which buffered metrics will be flushed
    ///   - maxMetricCount: Maximum number of metrics to batch before triggering an immediate flush.
    ///   - maxBufferSizeBytes: The maximum buffer size in bytes before triggering an immediate flush
    ///   - dateProvider: Instance used to determine current time
    ///   - dispatchQueue: A **serial** dispatch queue wrapper for thread-safe access to mutable state
    ///   - itemForwardingTriggers: Triggers that cause the buffer to flush (e.g. on app lifecycle events)
    ///   - capturedDataCallback: The callback to handle captured metric batches. This callback is responsible
    ///                          for invoking client.captureMetricsData() with the batched data.
    ///
    /// - Important: The `dispatchQueue` parameter MUST be a serial queue to ensure thread safety.
    ///              Passing a concurrent queue will result in undefined behavior and potential data races.
    ///
    /// - Note: Metrics are flushed when either `maxMetricCount` or `maxBufferSizeBytes` limit is reached.
    init(
        flushTimeout: TimeInterval = 5,
        maxMetricCount: Int = 100, // Maximum 100 metrics per batch
        maxBufferSizeBytes: Int = 1_024 * 1_024, // 1MB buffer size for trace metrics
        dateProvider: SentryCurrentDateProvider,
        dispatchQueue: SentryDispatchQueueWrapper,
        itemForwardingTriggers: TelemetryBufferItemForwardingTriggers,
        capturedDataCallback: @escaping (_ data: Data, _ count: Int) -> Void
    ) {
        self.buffer = DefaultTelemetryBuffer(
            config: .init(
                flushTimeout: flushTimeout,
                maxItemCount: maxMetricCount,
                maxBufferSizeBytes: maxBufferSizeBytes,
                capturedDataCallback: capturedDataCallback
            ),
            buffer: InMemoryInternalTelemetryBuffer(),
            dateProvider: dateProvider,
            dispatchQueue: dispatchQueue,
            itemForwardingTriggers: itemForwardingTriggers
        )
    }
    
    /// Adds a metric to the buffer.
    /// - Parameters:
    ///   - metric: The metric to add (should already have scope enrichment applied)
    func addMetric(_ metric: SentryMetric) {
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
