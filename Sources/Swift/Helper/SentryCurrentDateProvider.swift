@_implementationOnly import _SentryPrivate
import Foundation

#if TEST
@objcMembers
public class SentryCurrentDateProvider: NSObject {
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
#else
@objcMembers
class SentryCurrentDateProvider: NSObject {
    
    func date() -> Date {
        return Date()
    }

    func timezoneOffset() -> Int {
        return TimeZone.current.secondsFromGMT()
    }

    func systemTime() -> UInt64 {
        getAbsoluteTime()
    }
    
    func systemUptime() -> TimeInterval {
        ProcessInfo.processInfo.systemUptime
    }
}
#endif
