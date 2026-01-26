struct InMemoryInternalTelemetryBuffer<Item: Encodable>: InternalTelemetryBuffer {
    private var elements: [Data] = []
    var itemsDataSize: Int = 0

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }()

    init() {}

    mutating func append(_ item: Item) throws {
        let encoded = try encoder.encode(item)
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
