import Foundation

class TestRandom: SentryRandomProtocol {

    var value: Double
    
    init(value: Double) {
        self.value = value
    }
    
    func nextNumber() -> Double {
        return value
    }
}
