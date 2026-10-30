extension MetricKitSample {
    struct SearchService {
        @inline(never)
        func buildIndex(_ products: [Product]) -> [String: [Int]] {
            let deadline = ProcessInfo.processInfo.systemUptime + 0.25
            var index: [String: [Int]]
            repeat {
                index = [:]
                for (productID, product) in products.enumerated() {
                    for word in product.name.lowercased().split(separator: " ") {
                        index[String(word), default: []].append(productID)
                    }
                }
            } while ProcessInfo.processInfo.systemUptime < deadline
            return index
        }

        @inline(never)
        func rankProducts(_ products: [Product]) -> [Product] {
            let deadline = ProcessInfo.processInfo.systemUptime + 0.25
            var ranked: [Product]
            repeat {
                ranked = products.sorted {
                    $0.name.localizedStandardCompare($1.name) == .orderedAscending
                }
            } while ProcessInfo.processInfo.systemUptime < deadline
            return ranked
        }
    }
}
