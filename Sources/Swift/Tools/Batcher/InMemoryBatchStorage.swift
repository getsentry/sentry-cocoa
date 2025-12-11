struct InMemoryBatchStorage<Element: Encodable>: BatchStorage {
    private var elements: [Data] = []
    var size: Int = 0

    init() {}

    mutating func append(_ element: Element) throws {
        let encoded = try JSONEncoder().encode(element)
        elements.append(encoded)
        size += encoded.count
    }

    mutating func flush() {
        elements.removeAll()
        size = 0
    }

    var count: Int {
        elements.count
    }

    var data: Data {
        Data("{\"items\":[".utf8) + elements.joined(separator: Data(",".utf8)) + Data("]}".utf8)
    }
}
