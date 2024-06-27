@testable import Sentry
import XCTest

final class GaugeMetricTests: XCTestCase {

    func testAddingValues() throws {
        let sut = GaugeMetric(first: 1.0, key: "key", unit: MeasurementUnitDuration.hour, tags: [:])
        
        XCTAssertEqual(sut.serialize(), ["1.0", "1.0", "1.0", "1.0", "1"])
        
        sut.add(value: 5.0)
        sut.add(value: 4.0)
        sut.add(value: 3.0)
        sut.add(value: 2.0)
        sut.add(value: 2.5)
        sut.add(value: 1.0)
        
        XCTAssertEqual(sut.serialize(), [
            "1.0", // last
            "1.0", // min
            "5.0", // max
            "18.5", // sum
            "7"    // count
        ])
    }
    
    func testType() {
        let sut = GaugeMetric(first: 1.0, key: "key", unit: MeasurementUnitDuration.hour, tags: [:])
        
        XCTAssertEqual(sut.type, .gauge)
    }
    
    func testWeight() {
        let sut = GaugeMetric(first: 1.0, key: "key", unit: MeasurementUnitDuration.hour, tags: [:])
        
        XCTAssertEqual(sut.weight, 5)
        
        sut.add(value: 5.0)
        sut.add(value: 5.0)
        
        // The weight stays the same
        XCTAssertEqual(sut.weight, 5)
    }
}
