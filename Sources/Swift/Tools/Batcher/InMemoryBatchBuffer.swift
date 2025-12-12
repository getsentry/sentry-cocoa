struct InMemoryBatchBuffer<Item: Encodable>: BatchBuffer {
    private var elements: [Data] = []
    var itemsDataSize: Int = 0

    init() {}

    mutating func append(_ item: Item) throws {
        let encoded = try JSONEncoder().encode(item)
        elements.append(encoded)
        itemsDataSize += encoded.count
    }

    mutating func clear() {
        elements.removeAll()
        itemsDataSize = 0
    }

    var itemsCount: Int {
        elements.count
    }

    var batchedData: Data {
        Data("{\"items\":[".utf8) + elements.joined(separator: Data(",".utf8)) + Data("]}".utf8)
    }
}
