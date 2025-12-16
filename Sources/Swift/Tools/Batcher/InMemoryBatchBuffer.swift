struct InMemoryBatchBuffer<Item: Encodable>: BatchBuffer {
    private var wrapper: SentryBatchBufferWrapper?
    
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }()

    /// Initializes a new in-memory batch buffer.
    ///
    /// - Parameter capacity: The maximum capacity of the buffer in bytes. Defaults to 1MB.
    init(capacity: Int = 1_024 * 1_024) {
        do {
            self.wrapper = try SentryBatchBufferWrapper(capacity: capacity)
        } catch {
            SentrySDKLog.debug("InMemoryBatchBuffer: Could not init buffer.")
        }
    }

    mutating func append(_ item: Item) throws {
        guard let wrapper else {
            return
        }
        let encoded = try encoder.encode(item)
        guard wrapper.addItem(data: encoded) else {
            throw BatchBufferError.bufferFull
        }
    }

    mutating func clear() {
        wrapper?.clear()
    }

    var itemsCount: Int {
        wrapper?.itemCount ?? 0
    }
    
    var batchedData: Data {
        guard let wrapper else {
            return Data("{\"items\":[]}".utf8)
        }
        return wrapper.data
    }
}
