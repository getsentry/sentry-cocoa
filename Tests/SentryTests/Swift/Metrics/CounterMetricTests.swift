@testable import Sentry
import XCTest

final class CounterMetricTests: XCTestCase {

    func testAddingValues() {
        let sut = CounterMetric(first: 1.0, key: "key", unit: MeasurementUnitDuration.hour, tags: [:])
        
        sut.add(value: 1.0)
        sut.add(value: -1.0)
        sut.add(value: 2.0)
        
        XCTAssertEqual(sut.serialize(), ["3.0"])
    }
    
    func testType() {
        let sut = CounterMetric(first: 0.0, key: "key", unit: MeasurementUnitDuration.hour, tags: [:])
        
        XCTAssertEqual(sut.type, .counter)
    }
    
    func testWeight() {
        let sut = CounterMetric(first: 0.0, key: "key", unit: MeasurementUnitDuration.hour, tags: [:])
        
        XCTAssertEqual(sut.weight, 1)
        
        sut.add(value: 5.0)
        sut.add(value: 5.0)
        
        // The weight stays the same
        XCTAssertEqual(sut.weight, 1)
    }

}
