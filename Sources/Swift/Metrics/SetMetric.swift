import Foundation

class SetMetric: Metric {

    private var set: Set<Int32>
    var weight: UInt {
        return UInt(set.count)
    }

    init(first: Int32, key: String, unit: MeasurementUnit, tags: [String: String]) {
        set = [first]
        super.init(type: .set, key: key, unit: unit, tags: tags)
    }

    func add(value: Double) {
        set.insert(Int32(value))
    }

    func serialize() -> [String] {
        return set.map { "\($0)" }
    }
}
