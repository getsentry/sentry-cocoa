import Foundation
@_spi(Private) import Sentry

@_spi(Private)
public class TestRateLimits: NSObject, RateLimits {
    
    public var responses: [HTTPURLResponse] = []
    public var isLimitForAllActive: Bool = false
    public var rateLimits: [SentryDataCategory] = []
    
    public func isRateLimitActive(_ category: UInt) -> Bool {
        return isLimitForAllActive || rateLimits.contains(sentryDataCategoryForNSUInteger(category))
    }
    
    public func update(_ response: HTTPURLResponse) {
        responses.append(response)
    }
}
