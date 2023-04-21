import Foundation

@objc
public class TestCurrentDateProvider: NSObject, CurrentDateProvider {
    public static let defaultStartingDate = Date(timeIntervalSinceReferenceDate: 0)
    private var internalDate = defaultStartingDate
    private var internalSystemTime: UInt64 = 0
    public var driftTimeForEveryRead = false
    
    public func date() -> Date {

        defer {
            if driftTimeForEveryRead {
                internalDate = internalDate.addingTimeInterval(0.1)
            }
        }

        return internalDate
    }

    /// Reset the date provider to its default starting date.
    public func reset() {
        setDate(date: TestCurrentDateProvider.defaultStartingDate)
        internalSystemTime = 0
    }
    
    public func setDate(date: Date) {
        internalDate = date
    }

    /// Advance the current date by the specified number of seconds.
    public func advance(by seconds: TimeInterval) {
        setDate(date: date().addingTimeInterval(seconds))
        internalSystemTime += seconds.toNanoSeconds()
    }

    public func advanceBy(nanoseconds: UInt64) {
        setDate(date: date().addingTimeInterval(TimeInterval(nanoseconds) / 1e9))
        internalSystemTime += nanoseconds
    }
    
    public var internalDispatchNow = DispatchTime.now()
    public func dispatchTimeNow() -> dispatch_time_t {
        return internalDispatchNow.rawValue
    }

    public var timezoneOffsetValue = 0
    public func timezoneOffset() -> Int {
        return timezoneOffsetValue
    }

    public func systemTime() -> UInt64 {
        return internalSystemTime
    }
}
