import Foundation

class CounterMetric: Metric {

    private var value: Double = 0.0
    var weight: UInt = 1

    init(key: String, unit: MeasurementUnit, tags: [String: String]) {
        super.init(type: .counter, key: key, unit: unit, tags: tags)
    }

    func add(value: Double) {
        self.value += value
    }

    func serialize() -> [String] {
        return ["\(value)"]
    }

}
