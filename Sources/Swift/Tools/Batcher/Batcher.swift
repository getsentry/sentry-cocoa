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

    private var storage: Storage
    private let dateProvider: SentryCurrentDateProvider
    private let dispatchQueue: SentryDispatchQueueWrapperProtocol

    private var timerWorkItem: DispatchWorkItem?

    /// Initializes a new `Batcher`.
    /// - Parameters:
    ///   - config: The batcher configuration containing flush timeout, limits, and callbacks
    ///   - storage: The storage implementation for buffering items
    ///   - dateProvider: Provider for current date/time used for timing measurements
    ///   - dispatchQueue: A **serial** dispatch queue wrapper for thread-safe access to mutable state
    ///
    /// - Important: The `dispatchQueue` parameter MUST be a serial queue to ensure thread safety.
    ///              Passing a concurrent queue will result in undefined behavior and potential data races.
    ///
    /// - Note: Items are flushed when either `config.maxItemCount` or `config.maxBufferSizeBytes` limit is reached,
    ///        or after `config.flushTimeout` seconds have elapsed since the first item was added to an empty buffer.
    @_spi(Private) public init(
        config: Config,
        storage: Storage,
        dateProvider: SentryCurrentDateProvider,
        dispatchQueue: SentryDispatchQueueWrapperProtocol
    ) {
        self.config = config
        self.storage = storage
        self.dateProvider = dateProvider
        self.dispatchQueue = dispatchQueue
    }

    /// Adds an item to the batcher with the given scope.
    /// - Parameters:
    ///   - item: The item to add to the batch
    ///   - scope: The scope to apply to the item (adds attributes, trace ID, etc.)
    ///
    /// - Note: Scope application (attribute enrichment) and the `beforeSendItem` callback are executed
    ///        synchronously on the caller's thread. Only encoding and buffering happen asynchronously
    ///        on the batcher's serial dispatch queue. If `config.beforeSendItem` returns `nil`,
    ///        the item is dropped and not added to the batch.
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

    /// Captures all currently batched items synchronously and returns the duration of the operation.
    /// - Returns: The time taken to capture items in seconds
    ///
    /// - Note: This method blocks until all items are captured. The batcher's buffer is cleared after capture.
    ///
    /// - Important: This method uses `dispatchSync` to synchronously execute on the batcher's serial dispatch queue.
    ///              **Do not call this method from within the batcher's dispatch queue or from within the
    ///              `capturedDataCallback` closure**, as this will cause a deadlock. This method should only be
    ///              called from external threads or queues (e.g., main thread, app lifecycle callbacks).
    @discardableResult func capture() -> TimeInterval {
        let startTimeNs = dateProvider.getAbsoluteTime()
        dispatchQueue.dispatchSync { [weak self] in
            self?.performCaptureItems()
        }
        let endTimeNs = dateProvider.getAbsoluteTime()
        return TimeInterval(endTimeNs - startTimeNs) / 1_000_000_000.0 // Convert nanoseconds to seconds
    }

    /// Encodes and buffers an item, triggering a flush if limits are reached.
    ///
    /// - Important: Only call this method from the serial dispatch queue to ensure thread safety.
    /// - Parameter item: The item to encode and add to the buffer
    private func encodeAndBuffer(item: Item) {
        do {
            let encodedItemsWereEmpty = storage.itemsDataSize == 0
            try storage.append(item)

            // Flush when we reach max item count or max buffer size
            if storage.itemsCount >= config.maxItemCount || storage.itemsDataSize >= config.maxBufferSizeBytes {
                performCaptureItems()
            } else if encodedItemsWereEmpty && timerWorkItem == nil {
                startTimer()
            }
        } catch {
            SentrySDKLog.error("Failed to encode item: \(error)")
        }
    }
    
    /// Starts a timer that will trigger a flush after the configured timeout.
    ///
    /// - Important: Only call this method from the serial dispatch queue to ensure thread safety.
    ///
    /// - Note: The timer is only started when the buffer transitions from empty to non-empty.
    private func startTimer() {
        let timerWorkItem = DispatchWorkItem { [weak self] in
            SentrySDKLog.debug("Timer fired, calling performFlush().")
            self?.performCaptureItems()
        }
        self.timerWorkItem = timerWorkItem
        dispatchQueue.dispatch(after: config.flushTimeout, workItem: timerWorkItem)
    }

    /// Captures all buffered items by invoking the configured callback and clears the buffer.
    ///
    /// - Important: Only call this method from the serial dispatch queue to ensure thread safety.
    ///
    /// - Note: This method cancels any pending timer and clears the buffer after invoking the callback.
    ///        If the buffer is empty, the callback is not invoked.
    private func performCaptureItems() {
        // Reset items on function exit
        defer {
            storage.flush()
        }
        
        // Reset timer state
        timerWorkItem?.cancel()
        timerWorkItem = nil

        // Fetch and send any available data
        guard storage.itemsDataSize > 0 else {
            SentrySDKLog.debug("No items to flush.")
            return
        }
        config.capturedDataCallback(storage.batchedData, storage.itemsCount)
    }
}
