import Foundation

public class TestRandom: SentryRandomProtocol {

    public var value: Double
    
    public init(value: Double) {
        self.value = value
    }
    
    public func nextNumber() -> Double {
        return value
    }
}
