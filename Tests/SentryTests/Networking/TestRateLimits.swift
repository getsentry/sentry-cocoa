import Foundation

public class TestRateLimits : NSObject, RateLimits {
    
    public var responses : [HTTPURLResponse] = []
    public var isLimitForAllActive: Bool = false
    public var typeLimits : [String] = []
    
    public func isRateLimitActive(_ type: String) -> Bool {
        return isLimitForAllActive || typeLimits.contains(type)
    }
    
    public func update(_ response: HTTPURLResponse) {
        responses.append(response)
    }
}
