// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate
import Foundation

class SentryLogBuffer {
    private let buffer: any TelemetryBuffer<SentryLog>

    /// Convenience initializer with default flush timeout, max log count (100), and buffer size.
    /// Creates its own serial dispatch queue with DEFAULT QoS for thread-safe access to mutable state.
    /// - Parameters:
    ///   - dateProvider: The current date provider
    ///   - delegate: The delegate to handle captured log batches
    ///
    /// - Note: Uses DEFAULT priority (not LOW) because captureLogs() is called synchronously during
    ///         app lifecycle events (willResignActive, willTerminate) and needs to complete quickly.
    /// - Note: Setting `maxLogCount` to 100. While Replay hard limit is 1000, we keep this lower, as it's hard to lower once released.
    convenience init(
        dateProvider: SentryCurrentDateProvider,
        scheduler: any TelemetryScheduler,
        notificationCenter: SentryNSNotificationCenterWrapper
    ) {
        let dispatchQueue = SentryDispatchQueueWrapper(name: "io.sentry.log-batcher")
        self.init(
            flushTimeout: 5,
            maxLogCount: 100, // Maximum 100 logs per batch
            maxBufferSizeBytes: 1_024 * 1_024, // 1MB buffer size
            dateProvider: dateProvider,
            dispatchQueue: dispatchQueue,
            scheduler: scheduler,
            notificationCenter: notificationCenter
        )
    }

    /// Initializes a new SentryLogBuffer.
    /// - Parameters:
    ///   - flushTimeout: The timeout interval after which buffered logs will be flushed
    ///   - maxLogCount: Maximum number of logs to batch before triggering an immediate flush.
    ///   - maxBufferSizeBytes: The maximum buffer size in bytes before triggering an immediate flush
    ///   - dispatchQueue: A **serial** dispatch queue wrapper for thread-safe access to mutable state
    ///   - delegate: The delegate to handle captured log batches
    ///
    /// - Important: The `dispatchQueue` parameter MUST be a serial queue to ensure thread safety.
    ///              Passing a concurrent queue will result in undefined behavior and potential data races.
    ///
    /// - Note: Logs are flushed when either `maxLogCount` or `maxBufferSizeBytes` limit is reached.
    init(
        flushTimeout: TimeInterval,
        maxLogCount: Int,
        maxBufferSizeBytes: Int,
        dateProvider: SentryCurrentDateProvider,
        dispatchQueue: SentryDispatchQueueWrapper,
        scheduler: some TelemetryScheduler,
        notificationCenter: SentryNSNotificationCenterWrapper
    ) {
        self.buffer = DefaultTelemetryBuffer(
            config: .init(
                flushTimeout: flushTimeout,
                maxItemCount: maxLogCount,
                maxBufferSizeBytes: maxBufferSizeBytes,
                capturedDataCallback: { data, count in
                    scheduler.capture(data: data, count: count, telemetryType: .log)
                }
            ),
            buffer: InMemoryInternalTelemetryBuffer(),
            dateProvider: dateProvider,
            dispatchQueue: dispatchQueue,
            itemForwarding: DefaultTelemetryBufferDataForwardingTriggers(notificationCenter: notificationCenter)
        )
    }

    /// Adds a log to the buffer.
    /// - Parameters:
    ///   - log: The log to add (should already have scope enrichment applied)
    func addLog(_ log: SentryLog) {
        buffer.add(log)
    }

    /// Captures buffered logs sync and returns the duration.
    @discardableResult
    func captureLogs() -> TimeInterval {
        return buffer.capture()
    }
}

extension SentryLog: TelemetryItem {
    var attributesDict: [String: SentryAttributeContent] {
        get {
            attributes.mapValues { value in
                SentryAttributeContent.from(anyValue: value)
            }
        }
        set {
            attributes = newValue.mapValues { value in
                SentryAttribute(attributableValue: value)
            }
        }
    }
}
// swiftlint:enable missing_docs
