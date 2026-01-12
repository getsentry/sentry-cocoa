@_implementationOnly import _SentryPrivate
import Foundation

/// Errors that can occur when using `CrashSafeBatchBuffer`.
enum CrashSafeBatchBufferError: Error {
    case initializationFailed
}

/// A wrapper around the global crash-safe log buffer.
///
/// This class manages a buffer that is accessible from the crash handler during a crash.
/// The buffer is allocated in C memory and remains stable for the lifetime of this object.
///
/// - Important: Only one `CrashSafeBatchBuffer` should be active at a time.
///              Creating a new instance will destroy any previously created buffer.
final class CrashSafeBatchBuffer {
    
    /// Creates a new crash-safe batch buffer.
    /// - Parameters:
    ///   - dataCapacity: Maximum capacity in bytes for storing data
    ///   - itemsCapacity: Maximum number of items the buffer can hold
    init(dataCapacity: Int, itemsCapacity: Int) throws {
        guard sentrycrash_logSync_start(dataCapacity, itemsCapacity) else {
            throw CrashSafeBatchBufferError.initializationFailed
        }
    }
    
    deinit {
        sentrycrash_logSync_stop()
    }
    
    /// Adds raw data to the buffer.
    /// - Parameter data: The data to add
    /// - Returns: `true` if the item was successfully added, `false` if the buffer is full
    func addItem(_ data: Data) -> Bool {
        guard !data.isEmpty else {
            return true
        }
        guard let buffer = sentrycrash_logSync_getBuffer() else {
            return false
        }
        return data.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else {
                return false
            }
            return sentry_batch_buffer_add_item(buffer, baseAddress.assumingMemoryBound(to: CChar.self), data.count)
        }
    }
    
    func clear() {
        guard let buffer = sentrycrash_logSync_getBuffer() else {
            return
        }
        sentry_batch_buffer_clear(buffer)
    }
    
    var itemCount: Int {
        guard let buffer = sentrycrash_logSync_getBuffer() else {
            return 0
        }
        return Int(sentry_batch_buffer_get_item_count(buffer))
    }
    
    var dataSize: Int {
        guard let buffer = sentrycrash_logSync_getBuffer() else {
            return 0
        }
        return Int(sentry_batch_buffer_get_data_size(buffer))
    }
    
    func getAllItems() -> [Data] {
        guard let buffer = sentrycrash_logSync_getBuffer() else {
            return []
        }
        var items: [Data] = []
        let count = itemCount
        for i in 0..<count {
            var itemSize: size_t = 0
            guard let itemData = sentry_batch_buffer_get_item(buffer, i, &itemSize) else {
                continue
            }
            items.append(Data(bytes: itemData, count: Int(itemSize)))
        }
        return items
    }
}
