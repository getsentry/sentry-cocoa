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
final class CrashSafeBatchBuffer<Item: Encodable>: BatchBuffer {
    
    let lock = NSLock()
    
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }()
    
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
    
    // MARK: - BatchBuffer Protocol
    
    func append(_ item: Item) throws {
        let encoded = try encoder.encode(item)
        guard !encoded.isEmpty else {
            return
        }
        let success = lock.synchronized {
            guard let buffer = sentrycrash_logSync_getBuffer() else {
                return false
            }
            return encoded.withUnsafeBytes { bytes in
                guard let baseAddress = bytes.baseAddress else {
                    return false
                }
                return sentry_batch_buffer_add_item(buffer, baseAddress.assumingMemoryBound(to: CChar.self), encoded.count)
            }
        }
        if !success {
            throw BatchBufferError.bufferFull
        }
    }
    
    func clear() {
        lock.synchronized {
            guard let buffer = sentrycrash_logSync_getBuffer() else {
                return
            }
            sentry_batch_buffer_clear(buffer)
        }
    }
    
    var itemsCount: Int {
        return lock.synchronized {
            guard let buffer = sentrycrash_logSync_getBuffer() else {
                return 0
            }
            return Int(sentry_batch_buffer_get_item_count(buffer))
        }
    }
    
    var itemsDataSize: Int {
        return lock.synchronized {
            guard let buffer = sentrycrash_logSync_getBuffer() else {
                return 0
            }
            return Int(sentry_batch_buffer_get_data_size(buffer))
        }
    }
    
    var batchedData: Data {
        let elements: [Data] = lock.synchronized {
            guard let buffer = sentrycrash_logSync_getBuffer() else {
                return []
            }
            var items: [Data] = []
            let count = Int(sentry_batch_buffer_get_item_count(buffer))
            for i in 0..<count {
                var itemSize: size_t = 0
                guard let itemData = sentry_batch_buffer_get_item(buffer, i, &itemSize) else {
                    continue
                }
                items.append(Data(bytes: itemData, count: Int(itemSize)))
            }
            return items
        }
        return Data("{\"items\":[".utf8) + elements.joined(separator: Data(",".utf8)) + Data("]}".utf8)
    }
}
