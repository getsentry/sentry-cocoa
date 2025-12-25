struct InMemoryBatchBuffer<Item: Encodable>: BatchBuffer {
    private var crashSaveBatchBuffer: CrashSafeBatchBuffer?
    
    private var elements: [Data] = []
    private var elementsDataSize: Int = 0

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }()

    init(dataCapacity: Int, itemsCapacity: Int) {
        do {
            crashSaveBatchBuffer = try CrashSafeBatchBuffer(
                dataCapacity: dataCapacity * 2,
                itemsCapacity: itemsCapacity
            )
        } catch {
            let warningText = "InMemoryBatchBuffer: Could not init crash safe storage."
            SentrySDKLog.warning(warningText)
            assertionFailure(warningText)
        }
    }

    mutating func append(_ item: Item) throws {
        let encoded = try encoder.encode(item)
        
        if let buffer = crashSaveBatchBuffer {
            if !buffer.addItem(encoded) {
                throw BatchBufferError.bufferFull
            }
        } else {
            elements.append(encoded)
            elementsDataSize += encoded.count
        }
    }

    mutating func clear() {
        if let crashSaveBatchBuffer {
            crashSaveBatchBuffer.clear()
        } else {
            elements.removeAll()
            elementsDataSize = 0
        }
    }
    
    var itemsDataSize: Int {
        if let crashSaveBatchBuffer {
            return crashSaveBatchBuffer.dataSize
        } else {
            return elementsDataSize
        }
    }

    var itemsCount: Int {
        if let crashSaveBatchBuffer {
            return crashSaveBatchBuffer.itemCount
        } else {
            return elements.count
        }
    }

    var batchedData: Data {
        let elements: [Data]
        if let crashSaveBatchBuffer {
            elements = crashSaveBatchBuffer.getAllItems()
        } else {
            elements = self.elements
        }
        return Data("{\"items\":[".utf8) + elements.joined(separator: Data(",".utf8)) + Data("]}".utf8)
    }
}
