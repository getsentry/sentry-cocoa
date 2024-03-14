import Foundation

/// The bucket timestamp is calculated:
///     ( timeIntervalSince1970 / ROLLUP_IN_SECONDS ) * ROLLUP_IN_SECONDS
typealias BucketTimestamp = UInt64
private let ROLLUP_IN_SECONDS: TimeInterval = 10

typealias Metric = MetricBase & MetricProtocol

protocol MetricProtocol {

    var weight: UInt { get }
    func add(value: Double)
    func serialize() -> [String]
}

class MetricBase {

    let type: MetricType
    let key: String
    let unit: MeasurementUnit
    let tags: [String: String]

    init(type: MetricType, key: String, unit: MeasurementUnit, tags: [String: String]) {
        self.type = type
        self.key = key
        self.unit = unit
        self.tags = tags
    }
}

enum MetricType: Character {
    case counter = "c"
    case gauge = "g"
    case distribution = "d"
    case set = "s"
}
