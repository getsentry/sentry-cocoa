@_implementationOnly import _SentryPrivate
import Foundation

@objc @_spi(Private) public protocol SentryLogBatcherDelegate: AnyObject {
    @objc(captureLogsData:with:)
    func capture(logsData: NSData, count: NSNumber)
}

@objc
@objcMembers
@_spi(Private) public class SentryLogBatcher: NSObject {
    private let options: Options
    private let batcher: any BatcherProtocol<SentryLog, Scope>
    private weak var delegate: SentryLogBatcherDelegate?

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
        delegate: SentryLogBatcherDelegate
    ) {
        let dispatchQueue = SentryDispatchQueueWrapper(name: "io.sentry.log-batcher")
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

    /// Initializes a new SentryLogBatcher.
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
        delegate: SentryLogBatcherDelegate
    ) {
        self.batcher = Batcher(
            config: .init(
                environment: options.environment,
                releaseName: options.releaseName,
                flushTimeout: flushTimeout,
                maxItemCount: maxLogCount,
                maxBufferSizeBytes: maxBufferSizeBytes,
                beforeSendItem: options.beforeSendLog,
                getInstallationId: {
                    SentryInstallation.cachedId(withCacheDirectoryPath: options.cacheDirectoryPath)
                },
                capturedDataCallback: { [weak delegate] data, count in
                    guard let delegate else {
                        SentrySDKLog.debug("SentryLogBatcher: Delegate not set, not capturing logs data.")
                        return
                    }
                    delegate.capture(logsData: data as NSData, count: NSNumber(value: count))
                }
            ),
            buffer: InMemoryBatchBuffer(),
            dateProvider: dateProvider,
            dispatchQueue: dispatchQueue
        )
        self.options = options
        self.delegate = delegate
        super.init()
    }

    /// Adds a log to the batcher.
    /// - Parameters:
    ///   - log: The log to add
    ///   - scope: The scope to add the log to
    @_spi(Private) @objc public func addLog(_ log: SentryLog, scope: Scope) {
        guard options.enableLogs else {
            return
        }
        
        batcher.add(log, scope: scope)
    }

    /// Captures batched logs sync and returns the duration.
    @discardableResult
    @_spi(Private) @objc public func captureLogs() -> TimeInterval {
        return batcher.capture()
    }
}

extension SentryLog: BatcherItem {}
