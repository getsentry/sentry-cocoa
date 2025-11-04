import _SentryPrivate
import Foundation
@_spi(Private) @testable import Sentry

@_spi(Private) public class TestRandom: SentryRandomProtocol {

    public var value: Double
    
    public init(value: Double) {
        self.value = value
    }
    
    public func nextNumber() -> Double {
        return value
    }
}
