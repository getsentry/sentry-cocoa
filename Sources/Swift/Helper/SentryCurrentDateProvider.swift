import Foundation

/**
 * We need a protocol to expose SentryCurrentDateProvider to tests.
 * Mocking the previous private class from `SentryTestUtils` stopped working in Xcode 16.
*/
@objc
protocol SentryCurrentDateProvider {
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
        clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
    }
    
    func systemUptime() -> TimeInterval {
        ProcessInfo.processInfo.systemUptime
    }
}
