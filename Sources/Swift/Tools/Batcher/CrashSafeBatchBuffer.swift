@_implementationOnly import _SentryPrivate
import Foundation

/// Errors that can occur when using `CrashSafeBatchBuffer`.
enum CrashSafeBatchBufferError: Error {
    case initializationFailed
}

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
    
    func clear() {
        sentry_batch_buffer_clear(&buffer)
    }
    
    var itemCount: Int {
        return Int(sentry_batch_buffer_get_item_count(&buffer))
    }
    
    var dataSize: Int {
        return Int(sentry_batch_buffer_get_data_size(&buffer))
    }
    
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
