import Nimble
@testable import Sentry
import XCTest

final class GaugeMetricTests: XCTestCase {

    func testAddingValues() throws {
        let sut = GaugeMetric(first: 1.0, key: "key", unit: MeasurementUnitDuration.hour, tags: [:])
        
        expect(sut.serialize()).to(contain(["1.0", "1.0", "1.0", "1.0", "1"]))
        
        sut.add(value: 5.0)
        sut.add(value: 4.0)
        sut.add(value: 3.0)
        sut.add(value: 2.0)
        sut.add(value: 2.5)
        sut.add(value: 1.0)
        
        expect(sut.serialize()) == [
            "1.0", // last
            "1.0", // min
            "5.0", // max
            "18.5", // sum
            "7"    // count
        ]
    }
    
    func testType() {
        let sut = GaugeMetric(first: 1.0, key: "key", unit: MeasurementUnitDuration.hour, tags: [:])
        
        expect(sut.type) == .gauge
    }
    
    func testWeight() {
        let sut = GaugeMetric(first: 1.0, key: "key", unit: MeasurementUnitDuration.hour, tags: [:])
        
        expect(sut.weight) == 5
        
        sut.add(value: 5.0)
        sut.add(value: 5.0)
        
        // The weight stays the same
        expect(sut.weight) == 5
    }
}
