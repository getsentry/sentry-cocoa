@_implementationOnly import _SentryPrivate
import Foundation

@objcMembers class SentryCurrentDateProvider: NSObject {
    
    public func date() -> Date {
        return Date()
    }

    public func timezoneOffset() -> Int {
        return TimeZone.current.secondsFromGMT()
    }

    public func systemTime() -> UInt64 {
        getAbsoluteTime()
    }
    
    public func systemUptime() -> TimeInterval {
        ProcessInfo.processInfo.systemUptime
    }
}
