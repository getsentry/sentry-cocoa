@_implementationOnly import _SentryPrivate
import Foundation

protocol BatcherProtocol<Item, Scope>: AnyObject {
    associatedtype Item: BatcherItem
    associatedtype Scope: BatcherScope

    func add(_ item: Item, scope: Scope)
    func capture()
}

final class Batcher<Buffer: BatchBuffer<Item>, Item: BatcherItem, Scope: BatcherScope>: BatcherProtocol {
    struct Config: BatcherConfig {
        let sendDefaultPii: Bool

        let flushTimeout: TimeInterval
        let maxItemCount: Int
        let maxBufferSizeBytes: Int
        
        let beforeSendItem: ((Item) -> Item?)?

        var capturedDataCallback: (Data, Int) -> Void = { _, _ in }
    }

    struct Metadata: BatcherMetadata {
        let environment: String
        let releaseName: String?
        let installationId: String?
    }

    private let config: Config
    private let metadata: Metadata

    private var buffer: Buffer
    private let dateProvider: SentryCurrentDateProvider
    private let dispatchQueue: SentryDispatchQueueWrapperProtocol

    private var timerWorkItem: DispatchWorkItem?
    private let lock = NSLock()

    /// Initializes a new `Batcher`.
    /// - Parameters:
    ///   - config: The batcher configuration containing flush timeout, limits, and callbacks
    ///   - metadata: The batcher metadata containing fields like environment or release
    ///   - buffer: The buffer implementation for buffering items
    ///   - dateProvider: Provider for current date/time used for timing measurements
    ///   - dispatchQueue: A dispatch queue wrapper used only for timer scheduling
    ///
    /// - Note: Items are flushed when either `config.maxItemCount` or `config.maxBufferSizeBytes` limit is reached,
    ///        or after `config.flushTimeout` seconds have elapsed since the first item was added to an empty buffer.
    ///        All operations are synchronous and thread-safe using internal locking.
    @_spi(Private) public init(
        config: Config,
        metadata: Metadata,
        buffer: Buffer,
        dateProvider: SentryCurrentDateProvider,
        dispatchQueue: SentryDispatchQueueWrapperProtocol
    ) {
        self.config = config
        self.metadata = metadata
        self.buffer = buffer
        self.dateProvider = dateProvider
        self.dispatchQueue = dispatchQueue
    }

    /// Adds an item to the batcher with the given scope.
    /// - Parameters:
    ///   - item: The item to add to the batch
    ///   - scope: The scope to apply to the item (adds attributes, trace ID, etc.)
    ///
    /// - Note: All operations are executed synchronously on the caller's thread. Scope application,
    ///        attribute enrichment, the `beforeSendItem` callback, encoding, and buffering all happen
    ///        synchronously. If `config.beforeSendItem` returns `nil`, the item is dropped and not added to the batch.
    ///        Thread safety is ensured through internal locking.
    func add(_ item: Item, scope: Scope) {
        var item = item
        scope.applyToItem(&item, config: config, metadata: metadata)

        // The before send item closure can be used to drop items by returning nil
        // In case it is nil, we can stop processing
        if let beforeSendItem = config.beforeSendItem {
            // If the before send hook returns nil, the item should be dropped
            guard let processedItem = beforeSendItem(item) else {
                return
            }
            item = processedItem
        }

        encodeAndBuffer(item: item)
    }

    /// Captures all currently batched items synchronously and returns the duration of the operation.
    /// - Returns: The time taken to capture items in seconds (currently always returns 0)
    ///
    /// - Note: This method blocks until all items are captured. The batcher's buffer is cleared after capture.
    ///        Thread safety is ensured through internal locking.
    func capture() {
        performCaptureItems()
    }

    /// Encodes and buffers an item, triggering a flush if limits are reached.
    ///
    /// - Parameter item: The item to encode and add to the buffer
    /// - Note: Thread safety is ensured through internal locking.
    private func encodeAndBuffer(item: Item) {
        lock.synchronized {
            do {
                let encodedItemsWereEmpty = buffer.itemsDataSize == 0
                try buffer.append(item)

                // Flush when we reach max item count or max buffer size
                if buffer.itemsCount >= config.maxItemCount || buffer.itemsDataSize >= config.maxBufferSizeBytes {
                    performCaptureItemsLocked()
                } else if encodedItemsWereEmpty && timerWorkItem == nil {
                    startTimerLocked()
                }
            } catch {
                SentrySDKLog.error("Failed to encode item: \(error)")
            }
        }
    }
    
    /// Starts a timer that will trigger a flush after the configured timeout.
    ///
    /// - Note: The timer is only started when the buffer transitions from empty to non-empty.
    ///        Must be called while holding the lock.
    private func startTimerLocked() {
        let timerWorkItem = DispatchWorkItem { [weak self] in
            SentrySDKLog.debug("Timer fired, calling performFlush().")
            self?.performCaptureItems()
        }
        self.timerWorkItem = timerWorkItem
        dispatchQueue.dispatch(after: config.flushTimeout, workItem: timerWorkItem)
    }

    /// Captures all buffered items by invoking the configured callback and clears the buffer.
    ///
    /// - Note: This method cancels any pending timer and clears the buffer after invoking the callback.
    ///        If the buffer is empty, the callback is not invoked.
    ///        Thread safety is ensured through internal locking.
    private func performCaptureItems() {
        lock.synchronized {
            performCaptureItemsLocked()
        }
    }
    
    /// Internal implementation of capture that assumes the lock is already held.
    ///
    /// - Note: Must be called while holding the lock.
    private func performCaptureItemsLocked() {
        // Reset items on function exit
        defer {
            buffer.clear()
        }
        
        // Reset timer state
        timerWorkItem?.cancel()
        timerWorkItem = nil

        // Fetch and send any available data
        guard buffer.itemsCount > 0 else {
            SentrySDKLog.debug("No items to flush.")
            return
        }
        config.capturedDataCallback(buffer.batchedData, buffer.itemsCount)
    }
}
