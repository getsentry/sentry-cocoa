import Foundation

public class TestRateLimits : NSObject, RateLimits {
    
    public var responses : [HTTPURLResponse] = []
    public var isLimitRateReached: Bool = false
    
    public func isRateLimitReached() -> Bool {
        return isLimitRateReached
    }
    
    public func update(_ response: HTTPURLResponse) {
        responses.append(response)
    }
}
