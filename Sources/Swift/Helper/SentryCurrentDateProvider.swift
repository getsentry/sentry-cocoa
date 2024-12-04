@_implementationOnly import _SentryPrivate
import Foundation

/**
 * We need a protocol to expose SentryCurrentDateProvider to tests.
 * Mocking the previous private class from `SentryTestUtils` stopped working in Xcode 16.
*/
@objc
public protocol SentryCurrentDateProvider {
    func date() -> Date
    func timezoneOffset() -> Int
    func systemTime() -> UInt64
    func systemUptime() -> TimeInterval
}

@objcMembers
public class SentryDefaultCurrentDateProvider: NSObject, SentryCurrentDateProvider {
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
