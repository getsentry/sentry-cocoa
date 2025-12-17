@_implementationOnly import _SentryPrivate
import Foundation

/// A Swift wrapper around the C `SentryBatchBufferC` API.
///
/// This wrapper provides a Swift interface to the C batch buffer implementation.
/// It stores generic binary data items in a pre-allocated buffer.
///
/// - Note: Internally, the buffer uses double the specified capacity to allow items
///   slightly over the capacity to still be added. The public API reports the original capacity.
final class SentryBatchBufferWrapper {
    private var buffer: SentryBatchBufferC
    /// The original capacity requested by the user (not the doubled internal capacity).
    private let originalDataCapacity: Int
    
    /// Initializes a new C batch buffer with the specified capacities.
    ///
    /// - Parameters:
    ///   - dataCapacity: The maximum capacity of the data buffer in bytes.
    ///   - maxItems: The maximum number of items that can be stored.
    /// - Throws: An error if the buffer initialization fails.
    /// - Note: Internally, the buffer uses double the specified capacity to allow items
    ///   slightly over the capacity to still be added, but this is abstracted away.
    init(dataCapacity: Int, maxItems: Int) throws {
        self.originalDataCapacity = dataCapacity
        var cBuffer = SentryBatchBufferC()
        // Use double the capacity internally to allow items slightly over the capacity
        let internalCapacity = dataCapacity * 2
        guard sentry_batch_buffer_init(&cBuffer, internalCapacity, maxItems) else {
            throw SentryBatchBufferError.initializationFailed
        }
        self.buffer = cBuffer
    }
    
    deinit {
        sentry_batch_buffer_destroy(&buffer)
    }
    
    // Returns true if the item was successfully added, false if the buffer is full.
    @discardableResult
    func addItem(data: Data) -> Bool {
        guard !data.isEmpty else {
            return true
        }
        return data.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else {
                return false
            }
            return sentry_batch_buffer_add_item(&buffer, baseAddress.assumingMemoryBound(to: CChar.self), data.count)
        }
    }

    func getItems() -> [Data] {
        var items: [Data] = []
        let count = Int(sentry_batch_buffer_get_item_count(&buffer))
        for i in 0..<count {
            var itemSize: size_t = 0
            guard let itemData = sentry_batch_buffer_get_item(&buffer, i, &itemSize) else {
                continue
            }
            items.append(Data(bytes: itemData, count: Int(itemSize)))
        }
        return items
    }
    
    func clear() {
        sentry_batch_buffer_clear(&buffer)
    }
    
    var dataSize: Int {
        return Int(sentry_batch_buffer_get_data_size(&buffer))
    }
    
    var dataCapacity: Int {
        // Return the original capacity, not the doubled internal capacity
        return originalDataCapacity
    }
    
    var itemCount: Int {
        return Int(sentry_batch_buffer_get_item_count(&buffer))
    }
}

/// Errors that can occur when using `SentryBatchBufferWrapper`.
enum SentryBatchBufferError: Error {
    case initializationFailed
}
