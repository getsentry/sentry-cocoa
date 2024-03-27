import Foundation

class SetMetric: Metric {

    private var set: Set<UInt>
    var weight: UInt {
        return UInt(set.count)
    }

    init(first: UInt, key: String, unit: MeasurementUnit, tags: [String: String]) {
        set = [first]
        super.init(type: .set, key: key, unit: unit, tags: tags)
    }

    // This doesn't work with the full range of UInt.
    // We still need to fix this.
    func add(value: Double) {
        if value >= Double(UInt.min) && value < Double(UInt.max) {            set.insert(UInt(value))
        }
    }

    func serialize() -> [String] {
        return set.map { "\($0)" }
    }
}
