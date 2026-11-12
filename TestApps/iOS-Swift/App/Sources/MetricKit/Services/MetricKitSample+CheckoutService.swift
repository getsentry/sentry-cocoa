extension MetricKitSample {
    struct CheckoutService {
        private let serialization = SerializationService()
        private let pricing = PricingService()

        @inline(never)
        func checkout() throws -> Int {
            let products = try serialization.decodeProducts()
            let total = pricing.calculateTotal(products)
            let shipping = calculateShipping(products)
            let receipt = try serialization.encodeReceipt(products)
            return Int(total + shipping) + receipt.count
        }

        @inline(never)
        private func calculateShipping(_ products: [Product]) -> Double {
            let deadline = ProcessInfo.processInfo.systemUptime + 0.25
            var shipping = 0.0
            repeat {
                for zone in 1...100 {
                    shipping = products.reduce(0) { $0 + sqrt($1.price * Double(zone)) }
                }
            } while ProcessInfo.processInfo.systemUptime < deadline
            return shipping
        }
    }
}
