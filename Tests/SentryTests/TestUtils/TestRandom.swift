import Foundation

class TestRandom: RandomProtocol {

    var value: Double
    
    init(value: Double) {
        self.value = value
    }
    
    func nextNumber() -> Double {
        return value
    }
}
