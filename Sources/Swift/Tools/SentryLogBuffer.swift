// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate
import Foundation

@objc @_spi(Private) public protocol SentryLogBufferDelegate: AnyObject {
    @objc(captureLogsData:with:)
    func capture(logsData: NSData, count: NSNumber)
}

@objc
@objcMembers
@_spi(Private) public class SentryLogBuffer: NSObject {
    private let options: Options
    private let buffer: any TelemetryBuffer<SentryLog>
    private weak var delegate: SentryLogBufferDelegate?

    /// Convenience initializer with default flush timeout, max log count (100), and buffer size.
    /// Creates its own serial dispatch queue with DEFAULT QoS for thread-safe access to mutable state.
    /// - Parameters:
    ///   - options: The Sentry configuration options
    ///   - delegate: The delegate to handle captured log batches
    ///
    /// - Note: Uses DEFAULT priority (not LOW) because captureLogs() is called synchronously during
    ///         app lifecycle events (willResignActive, willTerminate) and needs to complete quickly.
    /// - Note: Setting `maxLogCount` to 100. While Replay hard limit is 1000, we keep this lower, as it's hard to lower once released.
    @_spi(Private) public convenience init(
        options: Options,
        dateProvider: SentryCurrentDateProvider,
        delegate: SentryLogBufferDelegate
    ) {
        let dispatchQueue = SentryDispatchQueueWrapper(name: "io.sentry.log-buffer")
        self.init(
            options: options,
            flushTimeout: 5,
            maxLogCount: 100, // Maximum 100 logs per batch
            maxBufferSizeBytes: 1_024 * 1_024, // 1MB buffer size
            dateProvider: dateProvider,
            dispatchQueue: dispatchQueue,
            delegate: delegate
        )
    }

    /// Initializes a new SentryLogBuffer.
    /// - Parameters:
    ///   - options: The Sentry configuration options
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
    @_spi(Private) public init(
        options: Options,
        flushTimeout: TimeInterval,
        maxLogCount: Int,
        maxBufferSizeBytes: Int,
        dateProvider: SentryCurrentDateProvider,
        dispatchQueue: SentryDispatchQueueWrapper,
        delegate: SentryLogBufferDelegate
    ) {
        self.buffer = DefaultTelemetryBuffer(
            config: .init(
                sendDefaultPii: options.sendDefaultPii,
                flushTimeout: flushTimeout,
                maxItemCount: maxLogCount,
                maxBufferSizeBytes: maxBufferSizeBytes,
                beforeSendItem: options.beforeSendLog,
                capturedDataCallback: { [weak delegate] data, count in
                    guard let delegate else {
                        SentrySDKLog.debug("SentryLogBuffer: Delegate not set, not capturing logs data.")
                        return
                    }
                    delegate.capture(logsData: data as NSData, count: NSNumber(value: count))
                }
            ),
            buffer: InMemoryInternalTelemetryBuffer(),
            dateProvider: dateProvider,
            dispatchQueue: dispatchQueue
        )
        self.options = options
        self.delegate = delegate
        super.init()
    }

    /// Adds a log to the buffer.
    /// - Parameters:
    ///   - log: The log to add (should already have scope enrichment applied)
    @_spi(Private) @objc public func addLog(_ log: SentryLog) {
        guard options.enableLogs else {
            return
        }

        buffer.add(log)
    }

    /// Captures buffered logs sync and returns the duration.
    @discardableResult
    @_spi(Private) @objc public func captureLogs() -> TimeInterval {
        return buffer.capture()
    }
}

extension SentryLog: TelemetryBufferItem {
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
