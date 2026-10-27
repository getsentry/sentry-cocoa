extension MetricKitSample {
    struct PricingService {
        @inline(never)
        func calculateTotal(_ products: [Product]) -> Double {
            let deadline = ProcessInfo.processInfo.systemUptime + 0.25
            var total = 0.0
            repeat {
                for discount in 1...100 {
                    total = products.reduce(0) { $0 + ($1.price * (1 - Double(discount) / 1_000)).rounded() }
                }
            } while ProcessInfo.processInfo.systemUptime < deadline
            return total
        }
    }
}
