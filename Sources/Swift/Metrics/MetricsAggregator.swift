import Foundation

protocol MetricsAggregator {
    func add(type: MetricType, key: String, value: Double, unit: MeasurementUnit, tags: [String: String])

    func flush(force: Bool)
    func close()
}

func getTagsKey(tags: [String: String]) -> String {
    // It's important to sort the tags in order to
    // obtain the same bucket key.
    return tags.sorted(by: { $0.key < $1.key }).map({ "\($0.key)=\($0.value)" }).joined(separator: ",")
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
