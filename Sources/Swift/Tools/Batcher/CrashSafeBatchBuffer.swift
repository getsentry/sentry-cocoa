@_implementationOnly import _SentryPrivate
import Foundation

/// A BatchBuffer that is using the `SentryBatchBufferC` as backend.
///
/// - Note: Internally, the buffer uses double the specified capacity to allow items
///   slightly over the capacity to still be added. The public API reports the original capacity.
final class CrashSafeBatchBuffer {
    private var buffer: SentryBatchBufferC
    /// The original capacity requested by the user (not the doubled internal capacity).
    private let originalDataCapacity: Int
    
    init(dataCapacity: Int, maxItems: Int) throws {
        self.originalDataCapacity = dataCapacity
        var cBuffer = SentryBatchBufferC()
        // Use double the capacity internally to allow items slightly over the capacity
        let internalCapacity = dataCapacity * 2
        guard sentry_batch_buffer_init(&cBuffer, internalCapacity, maxItems) else {
            throw CrashSafeBatchBufferError.initializationFailed
        }
        self.buffer = cBuffer
    }
    
    deinit {
        sentry_batch_buffer_destroy(&buffer)
    }
    
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

/// Errors that can occur when using `CrashSafeBatchBuffer`.
enum CrashSafeBatchBufferError: Error {
    case initializationFailed
}
