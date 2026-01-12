struct InMemoryBatchBuffer<Item: Encodable>: BatchBuffer {
    private var elements: [Data] = []
    private var elementsDataSize: Int = 0

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }()

    init(dataCapacity: Int, itemsCapacity: Int) {
        // InMemoryBatchBuffer is a simple in-memory fallback buffer
        // No initialization needed
    }

    mutating func append(_ item: Item) throws {
        let encoded = try encoder.encode(item)
        elements.append(encoded)
        elementsDataSize += encoded.count
    }

    mutating func clear() {
        elements.removeAll()
        elementsDataSize = 0
    }
    
    var itemsDataSize: Int {
        return elementsDataSize
    }

    var itemsCount: Int {
        return elements.count
    }

    var batchedData: Data {
        return Data("{\"items\":[".utf8) + elements.joined(separator: Data(",".utf8)) + Data("]}".utf8)
    }
}
