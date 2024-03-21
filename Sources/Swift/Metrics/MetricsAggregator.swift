import Foundation

let METRICS_AGGREGATOR_TOTAL_MAX_WEIGHT: UInt = 1_000
let METRICS_AGGREGATOR_FLUSH_INTERVAL: TimeInterval = 10.0
let METRICS_AGGREGATOR_FLUSH_TOLERANCE: TimeInterval = 0.5

protocol MetricsAggregator {
    func add(type: MetricType, key: String, value: Double, unit: MeasurementUnit, tags: [String: String])

    func flush(force: Bool)
    func close()
}

class NoOpMetricsAggregator: MetricsAggregator {

    func add(type: MetricType, key: String, value: Double, unit: MeasurementUnit, tags: [String: String]) {
        // empty on purpose
    }

    func flush(force: Bool) {
        // empty on purpose
    }

    func close() {
        // empty on purpose
    }
}
