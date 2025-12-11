@_implementationOnly import _SentryPrivate
import Foundation

protocol BatcherProtocol<Item, Scope>: AnyObject {
    associatedtype Item: BatcherItem
    associatedtype Scope: BatcherScope

    func add(_ item: Item, scope: Scope)
    func capture() -> TimeInterval
}

final class Batcher<Storage: BatchStorage<Item>, Item: BatcherItem, Scope: BatcherScope>: BatcherProtocol {
    struct Config: BatcherConfig {
        let environment: String
        let releaseName: String?
        let flushTimeout: TimeInterval
        let maxItemCount: Int
        let maxBufferSizeBytes: Int
        let beforeSendItem: ((Item) -> Item?)?
        let getInstallationId: () -> String?

        var capturedDataCallback: (Data, Int) -> Void = { _, _ in }
    }

    private let config: Config

    private var batchStorage: Storage
    private let dateProvider: SentryCurrentDateProvider
    private let dispatchQueue: SentryDispatchQueueWrapperProtocol

    private var timerWorkItem: DispatchWorkItem?

    /// Initializes a new SentryItemBatcher.
    /// - Parameters:
    ///   - options: The Sentry configuration options
    ///   - flushTimeout: The timeout interval after which buffered items will be flushed
    ///   - maxItemCount: Maximum number of items to batch before triggering an immediate flush.
    ///   - maxBufferSizeBytes: The maximum buffer size in bytes before triggering an immediate flush
    ///   - dispatchQueue: A **serial** dispatch queue wrapper for thread-safe access to mutable state
    ///
    /// - Important: The `dispatchQueue` parameter MUST be a serial queue to ensure thread safety.
    ///              Passing a concurrent queue will result in undefined behavior and potential data races.
    ///
    /// - Note: Items are flushed when either `maxItemCount` or `maxBufferSizeBytes` limit is reached.
    @_spi(Private) public init(
        config: Config,
        batchStorage: Storage,
        dateProvider: SentryCurrentDateProvider,
        dispatchQueue: SentryDispatchQueueWrapperProtocol
    ) {
        self.config = config
        self.batchStorage = batchStorage
        self.dateProvider = dateProvider
        self.dispatchQueue = dispatchQueue
    }

    func add(_ item: Item, scope: Scope) {
        var item = item
        scope.applyToItem(&item, config: config)

        // The before send item closure can be used to drop items by returning nil
        // In case it is nil, we can stop processing
        if let beforeSendItem = config.beforeSendItem {
            // If the before send hook returns nil, the item should be dropped
            guard let processedItem = beforeSendItem(item) else {
                return
            }
            item = processedItem
        }

        dispatchQueue.dispatchAsync { [weak self] in
            self?.encodeAndBuffer(item: item)
        }
    }

    // Captures batched items sync and returns the duration.
    @discardableResult func capture() -> TimeInterval {
        let startTimeNs = dateProvider.getAbsoluteTime()
        dispatchQueue.dispatchSync { [weak self] in
            self?.performCaptureItems()
        }
        let endTimeNs = dateProvider.getAbsoluteTime()
        return TimeInterval(endTimeNs - startTimeNs) / 1_000_000_000.0 // Convert nanoseconds to seconds
    }

    // Only ever call this from the serial dispatch queue.
    private func encodeAndBuffer(item: Item) {
        do {
            let encodedItemsWereEmpty = batchStorage.size == 0
            try batchStorage.append(item)

            // Flush when we reach max item count or max buffer size
            if batchStorage.count >= config.maxItemCount || batchStorage.size >= config.maxBufferSizeBytes {
                performCaptureItems()
            } else if encodedItemsWereEmpty && timerWorkItem == nil {
                startTimer()
            }
        } catch {
            SentrySDKLog.error("Failed to encode item: \(error)")
        }
    }
    
    // Only ever call this from the serial dispatch queue.
    private func startTimer() {
        let timerWorkItem = DispatchWorkItem { [weak self] in
            SentrySDKLog.debug("Timer fired, calling performFlush().")
            self?.performCaptureItems()
        }
        self.timerWorkItem = timerWorkItem
        dispatchQueue.dispatch(after: config.flushTimeout, workItem: timerWorkItem)
    }

    // Only ever call this from the serial dispatch queue.
    private func performCaptureItems() {
        // Reset items on function exit
        defer {
            batchStorage.flush()
        }
        
        // Reset timer state
        timerWorkItem?.cancel()
        timerWorkItem = nil

        // Fetch and send any available data
        guard batchStorage.size > 0 else {
            SentrySDKLog.debug("No items to flush.")
            return
        }
        config.capturedDataCallback(batchStorage.data, batchStorage.size)
    }
}
