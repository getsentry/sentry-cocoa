import Foundation

@objc
public class TestCurrentDateProvider : NSObject, CurrentDateProvider {
    
    public func date() -> Date {
        return Date(timeIntervalSinceReferenceDate: 0)
    }
}
