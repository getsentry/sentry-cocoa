import Nimble
@testable import Sentry
import XCTest

final class SetMetricTests: XCTestCase {

    func testAddingValues() {
        let sut = SetMetric(first: 1, key: "key", unit: MeasurementUnitDuration.hour, tags: [:])
        
        sut.add(value: 0.0)
        sut.add(value: -1.0)
        sut.add(value: -1.1)
        sut.add(value: 2.0)
        
        expect(sut.serialize()).to(contain(["1", "0", "-1", "2"]))
    }
    
    func testType() {
        let sut = SetMetric(first: 0, key: "key", unit: MeasurementUnitDuration.hour, tags: [:])
        
        expect(sut.type) == .set
    }
    
    func testWeight() {
        let sut = SetMetric(first: 1, key: "key", unit: MeasurementUnitDuration.hour, tags: [:])
        
        expect(sut.weight) == 1
        
        for _ in 0..<10 {
            sut.add(value: 5.0)
        }
        
        sut.add(value: -1.0)
        sut.add(value: 2.0)
        
        expect(sut.weight) == 4
    }

}
