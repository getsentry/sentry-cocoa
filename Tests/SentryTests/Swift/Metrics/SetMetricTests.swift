import Nimble
@testable import Sentry
import XCTest

final class SetMetricTests: XCTestCase {

    func testAddingValues() {
        let sut = SetMetric(first: 1, key: "key", unit: MeasurementUnitDuration.hour, tags: [:])
        
        sut.add(value: 0)
        sut.add(value: 1)
        sut.add(value: 2)
        
        expect(sut.serialize()).to(contain(["1", "0", "2"]))
    }
    
    func testAddUIntMax() {
        let sut = SetMetric(first: 1, key: "key", unit: MeasurementUnitDuration.hour, tags: [:])
        
        sut.add(value: UInt.max)
        
        expect(sut.serialize()).to(contain(["\(UInt.max)"]))
    }
    
    func testType() {
        let sut = SetMetric(first: 0, key: "key", unit: MeasurementUnitDuration.hour, tags: [:])
        
        expect(sut.type) == .set
    }
    
    func testWeight() {
        let sut = SetMetric(first: 1, key: "key", unit: MeasurementUnitDuration.hour, tags: [:])
        
        expect(sut.weight) == 1
        
        for _ in 0..<10 {
            sut.add(value: 5)
        }
        
        sut.add(value: 3)
        sut.add(value: 2)
        
        expect(sut.weight) == 4
    }

}
