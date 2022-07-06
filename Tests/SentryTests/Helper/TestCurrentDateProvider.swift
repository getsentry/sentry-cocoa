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
    
    var internalDispatchNow = DispatchTime.now()
    public func dispatchTimeNow() -> dispatch_time_t {
        return internalDispatchNow.rawValue
    }

    var timezoneOffsetValue = 0
    public func timezoneOffset() -> Int {
        return timezoneOffsetValue
    }
}
