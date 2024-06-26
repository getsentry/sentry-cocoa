@testable import Sentry
import XCTest

final class DistributionMetricTests: XCTestCase {

    func testAddingValues() {
        let sut = DistributionMetric(first: 1.0, key: "key", unit: MeasurementUnitDuration.hour, tags: [:])
        
        sut.add(value: 0.0)
        sut.add(value: -1.0)
        sut.add(value: 2.0)
        
        XCTAssertEqual(sut.serialize(), ["1.0", "0.0", "-1.0", "2.0"])
    }
    
    func testType() {
        let sut = DistributionMetric(first: 0.0, key: "key", unit: MeasurementUnitDuration.hour, tags: [:])
        
        XCTAssertEqual(sut.type, .distribution)
    }
    
    func testWeight() {
        let sut = DistributionMetric(first: 0.0, key: "key", unit: MeasurementUnitDuration.hour, tags: [:])
        
        XCTAssertEqual(sut.weight, 1)
        
        for _ in 0..<100 {
            sut.add(value: 5.0)
        }
        
        XCTAssertEqual(sut.weight, 101)
    }

}
