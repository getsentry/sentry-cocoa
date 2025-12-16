@_implementationOnly import _SentryPrivate
import Foundation

/// A Swift wrapper around the C `SentryBatchBuffer` API.
///
/// This wrapper provides a Swift interface to the C batch buffer implementation.
/// It exposes the C API functions directly without implementing any protocols.
///
/// - Note: The C buffer has a fixed capacity and will fail to add items if the capacity is exceeded.
final class SentryBatchBufferWrapper {
    private var buffer: SentryBatchBuffer
    
    /// Initializes a new C batch buffer with the specified capacity.
    ///
    /// - Parameter capacity: The maximum capacity of the buffer in bytes.
    /// - Throws: An error if the buffer initialization fails.
    init(capacity: Int) throws {
        var cBuffer = SentryBatchBuffer()
        guard sentry_batch_buffer_init(&cBuffer, capacity) else {
            throw SentryBatchBufferError.initializationFailed
        }
        self.buffer = cBuffer
    }
    
    deinit {
        sentry_batch_buffer_destroy(&buffer)
    }
    
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
    
    /// Clears all items from the buffer.
    func clear() {
        sentry_batch_buffer_clear(&buffer)
    }
    
    /// The buffer's complete data including prefix and suffix.
    /// Always contains valid JSON: either {"items":[]} when empty, or {"items":[item1,item2]} when items are present.
    var data: Data {
        guard let cData = sentry_batch_buffer_get_data(&buffer),
              dataSize > 0 else {
            // This should not happen as buffer is initialized with empty payload
            return Data("{\"items\":[]}".utf8)
        }
        // The buffer always contains the complete JSON structure
        return Data(bytes: cData, count: dataSize)
    }
    
    /// The current data size of the buffer in bytes.
    var dataSize: Int {
        return Int(sentry_batch_buffer_get_data_size(&buffer))
    }
    
    /// The current data capacity of the buffer in bytes.
    var dataCapacity: Int {
        return Int(sentry_batch_buffer_get_data_capacity(&buffer))
    }
    
    /// The current item count in the buffer.
    var itemCount: Int {
        return Int(sentry_batch_buffer_get_item_count(&buffer))
    }
}

/// Errors that can occur when using `SentryBatchBufferWrapper`.
enum SentryBatchBufferError: Error {
    case initializationFailed
}
