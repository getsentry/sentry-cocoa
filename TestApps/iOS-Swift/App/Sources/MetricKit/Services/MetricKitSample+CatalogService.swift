extension MetricKitSample {
    struct CatalogService {
        private let serialization = SerializationService()
        private let pricing = PricingService()
        private let search = SearchService()

        @inline(never)
        func refreshCatalog() throws -> Int {
            // Keep service frames in optimized builds. Each leaf does real CPU work for ~250 ms rather
            // than sleeping or funneling every sample into a shared busy-wait function.
            let products = try serialization.decodeProducts()
            let total = pricing.calculateTotal(products)
            let index = search.buildIndex(products)
            let matches = search.rankProducts(products)
            return Int(total) + index.count + matches.count
        }
    }
}
