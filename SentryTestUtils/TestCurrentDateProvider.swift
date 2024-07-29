import Foundation
@testable import Sentry

public class TestCurrentDateProvider: SentryCurrentDateProvider {
    public static let defaultStartingDate = Date(timeIntervalSinceReferenceDate: 0)
    private var internalDate = defaultStartingDate
    private var internalSystemTime: UInt64 = 0
    public var driftTimeForEveryRead = false
    public var driftTimeInterval = 0.1
    private var _systemUptime: TimeInterval = 0
    
    public override init() {
        
    }
    
    public override func date() -> Date {

        defer {
            if driftTimeForEveryRead {
                internalDate = internalDate.addingTimeInterval(driftTimeInterval)
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
        setDate(date: date().addingTimeInterval(nanoseconds.toTimeInterval()))
        internalSystemTime += nanoseconds
    }
    
    public func advanceBy(interval: TimeInterval) {
        setDate(date: date().addingTimeInterval(interval))
        internalSystemTime += interval.toNanoSeconds()
    }

    public var timezoneOffsetValue = 0
    public override func timezoneOffset() -> Int {
        return timezoneOffsetValue
    }

    public override func systemTime() -> UInt64 {
        return internalSystemTime
    }
    
    override public func systemUptime() -> TimeInterval {
        _systemUptime
    }
    public func setSystemUptime(_ uptime: TimeInterval) {
        _systemUptime = uptime
    }
}
