import Foundation

@objc
public class TestCurrentDateProvider: NSObject, CurrentDateProvider {
    
    private var internalDate = Date(timeIntervalSinceReferenceDate: 0)
    
    public func date() -> Date {
        internalDate
    }
    
    public func setDate(date: Date) {
        internalDate = date
    }
}
