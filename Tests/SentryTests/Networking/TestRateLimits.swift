#if SWIFT_PACKAGE
#if !SDK_V10
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
#else
@_spi(Private) import Sentry
#endif
import Foundation

@_spi(Private)
public class TestRateLimits: NSObject, RateLimits {
    
    public var responses: [HTTPURLResponse] = []
    public var isLimitForAllActive: Bool = false
    public var rateLimits: [SentryDataCategory] = []
    
    public func isRateLimitActive(_ category: SentryDataCategory) -> Bool {
        return isLimitForAllActive || rateLimits.contains(category)
    }
    
    public func update(_ response: HTTPURLResponse) {
        responses.append(response)
    }
}
