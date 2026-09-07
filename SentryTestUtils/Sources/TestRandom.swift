#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import _SentryPrivate
import Foundation

@_spi(Private) public class TestRandom: SentryRandomProtocol {

    public var value: Double
    
    public init(value: Double) {
        self.value = value
    }
    
    public func nextNumber() -> Double {
        return value
    }
}
