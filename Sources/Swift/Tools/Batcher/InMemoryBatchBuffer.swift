struct InMemoryBatchBuffer<Item: Encodable>: BatchBuffer {
    private var wrapper: SentryBatchBufferWrapper?

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }()

    init(dataCapacity: Int, maxItems: Int) {
        do {
            self.wrapper = try SentryBatchBufferWrapper(dataCapacity: dataCapacity, maxItems: maxItems)
        } catch {
            SentrySDKLog.error("InMemoryBatchBuffer could not create buffer backend.")
            self.wrapper = nil
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
        guard let wrapper else {
            return
        }
        wrapper.clear()
    }

    var itemsCount: Int {
        wrapper?.itemCount ?? 0
    }

    var itemsDataSize: Int {
        wrapper?.dataSize ?? 0
    }

    var batchedData: Data {
        guard let wrapper else {
            return Data("{\"items\":[]}".utf8)
        }
        let items = wrapper.getItems()
        return Data("{\"items\":[".utf8) + items.joined(separator: Data(",".utf8)) + Data("]}".utf8)
    }
}
