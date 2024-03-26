import Foundation

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
