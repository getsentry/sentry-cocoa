import Foundation
@testable import Sentry

public class TestCurrentDateProvider: SentryCurrentDateProvider {

    public static let defaultStartingDate = Date(timeIntervalSinceReferenceDate: 0)

    private var internalDate = defaultStartingDate
    private var internalSystemTime: UInt64 = 0

    public var driftTimeForEveryRead = false
    public var driftTimeInterval = 0.1

    private var _systemUptime: TimeInterval = 0

    // NSLock isn't reentrant, so we use NSRecursiveLock.
    private let lock = NSRecursiveLock()

    public init() {
    }

    public func date() -> Date {
        return lock.synchronized {
            defer {
                if driftTimeForEveryRead {
                    internalDate = internalDate.addingTimeInterval(driftTimeInterval)
                }
            }

            return internalDate
        }
    }

    /// Reset the date provider to its default starting date.
    public func reset() {
        lock.synchronized {
            setDate(date: TestCurrentDateProvider.defaultStartingDate)
            internalSystemTime = 0
        }
    }

    public func setDate(date: Date) {
        lock.synchronized {
            internalDate = date
        }
    }

    /// Advance the current date by the specified number of seconds.
    public func advance(by seconds: TimeInterval) {
        lock.synchronized {
            setDate(date: date().addingTimeInterval(seconds))
            internalSystemTime += seconds.toNanoSeconds()
        }
    }

    public func advanceBy(nanoseconds: UInt64) {
        lock.synchronized {
            setDate(date: date().addingTimeInterval(nanoseconds.toTimeInterval()))
            internalSystemTime += nanoseconds
        }
    }

    public func advanceBy(interval: TimeInterval) {
        lock.synchronized {
            setDate(date: date().addingTimeInterval(interval))
            internalSystemTime += interval.toNanoSeconds()
        }
    }

    public func systemTime() -> UInt64 {
        lock.synchronized {
            return internalSystemTime
        }
    }
    public func systemUptime() -> TimeInterval {
        return lock.synchronized {
            return _systemUptime
        }
    }
    public func setSystemUptime(_ uptime: TimeInterval) {
        lock.synchronized {
            _systemUptime = uptime
        }
    }

    private var _timezoneOffsetValue = 0
    public var timezoneOffsetValue: Int {
        get {
            return lock.synchronized {
                return _timezoneOffsetValue
            }
        }
        set {
            lock.synchronized {
                _timezoneOffsetValue = newValue
            }
        }
    }
    public func timezoneOffset() -> Int {
        return lock.synchronized {
            return _timezoneOffsetValue
        }
    }
}
