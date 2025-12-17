@_implementationOnly import _SentryPrivate
import Foundation

/// A wrapper around the `SentryBatchBufferC` C API.
final class CrashSafeBatchBuffer {
    private var buffer: SentryBatchBufferC
    
    init(dataCapacity: Int, itemsCapacity: Int) throws {
        var cBuffer = SentryBatchBufferC()
        guard sentry_batch_buffer_init(&cBuffer, dataCapacity, itemsCapacity) else {
            throw CrashSafeBatchBufferError.initializationFailed
        }
        self.buffer = cBuffer
    }
    
    deinit {
        sentry_batch_buffer_destroy(&buffer)
    }
    
    /// Adds raw data to the buffer.
    /// - Parameter data: The data to add
    /// - Returns: `true` if the item was successfully added, `false` if the buffer is full
    func addItem(_ data: Data) -> Bool {
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
    
    /// Clears all items from the buffer.
    func clear() {
        sentry_batch_buffer_clear(&buffer)
    }
    
    /// Returns the number of items in the buffer.
    var itemCount: Int {
        return Int(sentry_batch_buffer_get_item_count(&buffer))
    }
    
    /// Returns the total size of all data in the buffer.
    var dataSize: Int {
        return Int(sentry_batch_buffer_get_data_size(&buffer))
    }
    
    /// Gets all items in the buffer.
    /// - Returns: An array of all item data
    func getAllItems() -> [Data] {
        var items: [Data] = []
        let count = itemCount
        for i in 0..<count {
            var itemSize: size_t = 0
            guard let itemData = sentry_batch_buffer_get_item(&buffer, i, &itemSize) else {
                continue
            }
            items.append(Data(bytes: itemData, count: Int(itemSize)))
        }
        return items
    }
}

/// Errors that can occur when using `CrashSafeBatchBuffer`.
enum CrashSafeBatchBufferError: Error {
    case initializationFailed
}
