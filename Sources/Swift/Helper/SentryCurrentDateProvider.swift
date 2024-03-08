@_implementationOnly import _SentryPrivate

@objcMembers class SentryCurrentDateProvider: NSObject {

    func date() -> Date {
        return Date()
    }

    func timezoneOffset() -> Int {
        return TimeZone.current.secondsFromGMT()
    }

    func systemTime() -> UInt64 {
        getAbsoluteTime()
    }
}
