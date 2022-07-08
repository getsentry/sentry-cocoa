import Foundation

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
