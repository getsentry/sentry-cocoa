import Foundation

@objc
public class TestCurrentDateProvider: NSObject, CurrentDateProvider {
    
    private var internalDate = Date(timeIntervalSinceReferenceDate: 0)

    public var driftTimeForEveryRead = false
    
    public func date() -> Date {

        defer {
            if driftTimeForEveryRead {
                internalDate = internalDate.addingTimeInterval(0.1)
            }
        }

        return internalDate
    }
    
    public func setDate(date: Date) {
        internalDate = date
    }
    
    public var internalDispatchNow = DispatchTime.now()
    public func dispatchTimeNow() -> dispatch_time_t {
        return internalDispatchNow.rawValue
    }

    public var timezoneOffsetValue = 0
    public func timezoneOffset() -> Int {
        return timezoneOffsetValue
    }
}
