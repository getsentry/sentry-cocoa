@_implementationOnly import _SentryPrivate
import Foundation

@objc
protocol SentryCurrentDateProvider: NSObjectProtocol {
    func date() -> Date
    func timezoneOffset() -> Int
    func systemTime() -> UInt64
    func systemUptime() -> TimeInterval
}

@objcMembers
class SentryDefaultCurrentDateProvider: NSObject, SentryCurrentDateProvider {
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
