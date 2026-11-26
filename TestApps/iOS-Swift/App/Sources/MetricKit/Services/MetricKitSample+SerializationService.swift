extension MetricKitSample {
    struct SerializationService {
        private static let payload = Data(
            ("[" + (0..<200).map { "{\"name\":\"Product \($0)\",\"price\":\($0 + 1)}" }.joined(separator: ",") + "]").utf8
        )

        @inline(never)
        func decodeProducts() throws -> [Product] {
            let deadline = ProcessInfo.processInfo.systemUptime + 0.25
            let decoder = JSONDecoder()
            var products: [Product]
            repeat {
                products = try decoder.decode([Product].self, from: Self.payload)
            } while ProcessInfo.processInfo.systemUptime < deadline
            return products
        }

        @inline(never)
        func encodeReceipt(_ products: [Product]) throws -> Data {
            let deadline = ProcessInfo.processInfo.systemUptime + 0.25
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            var receipt: Data
            repeat {
                receipt = try encoder.encode(products)
            } while ProcessInfo.processInfo.systemUptime < deadline
            return receipt
        }
    }
}
