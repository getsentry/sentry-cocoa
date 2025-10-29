@_implementationOnly import _SentryPrivate
import Foundation

/// A wrapper around sysctl for testability.
@_spi(Private) @objc public class SentrySysctl: NSObject {
    
    private let runtimeInit = SentryRuntimeInit()
    
    /// Returns the time the system was booted with a precision of microseconds.
    ///
    /// @warning We must not send this information off device because Apple forbids that.
    /// We are allowed send the amount of time that has elapsed between events that occurred within the
    /// app though. For more information see
    /// https://developer.apple.com/documentation/bundleresources/privacy_manifest_files/describing_use_of_required_reason_api#4278394.
    ///
    /// @note This property is intentionally marked as internal to prevent accidental misuse.
    /// It should only be used to create SentryAppState objects for tracking system reboots.
    /// Never send this timestamp off device. See https://github.com/getsentry/sentry-cocoa/issues/6233
    @objc internal var systemBootTimestamp: Date {
        // This is the ONLY place where the system boot time sysctl should be accessed.
        // The SwiftLint rule ensures it is not used anywhere else in the codebase.
        // swiftlint:disable:next avoid_system_boot_timestamp
        let value = sentrycrashsysctl_timeval(CTL_KERN, KERN_BOOTTIME)
        return Date(timeIntervalSince1970: TimeInterval(value.tv_sec) + TimeInterval(value.tv_usec) / 1E6)
    }
    
    @objc public var processStartTimestamp: Date {
        let startTime = sentrycrashsysctl_currentProcessStartTime()
        return Date(timeIntervalSince1970: TimeInterval(startTime.tv_sec) + TimeInterval(startTime.tv_usec) / 1E6)
    }
    
    /// The system time that the process started, as measured in @c SentryRuntimeInit.load, essentially the
    /// earliest time we can record a system timestamp, which is the number of nanoseconds since the
    /// device booted, which is why we can't simply convert @c processStartTimestamp to the nanosecond
    /// representation of its @c timeIntervalSinceReferenceDate .
    @objc public var runtimeInitSystemTimestamp: UInt64 {
        runtimeInit.runtimeInitSystemTimestamp
    }
    
    @objc public var runtimeInitTimestamp: Date {
        runtimeInit.runtimeInitTimestamp
    }
    
    @objc public var moduleInitializationTimestamp: Date {
        runtimeInit.moduleInitializationTimestamp
    }
}
