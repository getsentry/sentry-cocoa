// swiftlint:disable missing_docs
internal import _SentryPrivate
import Darwin

protocol SentryDebuggerStatusProvider: AnyObject {
    var isBeingTraced: Bool { get }
}

final class SentryDefaultDebuggerStatusProvider: SentryDebuggerStatusProvider {
    typealias ProcessFlagsProvider = () -> Int32?

    private let processFlagsProvider: ProcessFlagsProvider

    convenience init() {
        self.init(processFlagsProvider: Self.currentProcessFlags)
    }

    init(processFlagsProvider: @escaping ProcessFlagsProvider) {
        self.processFlagsProvider = processFlagsProvider
    }

    var isBeingTraced: Bool {
        guard let processFlags = processFlagsProvider() else {
            SentrySDKLog.error("Failed to determine whether the process is being traced.")
            return false
        }
        return processFlags & P_TRACED != 0
    }

    private static func currentProcessFlags() -> Int32? {
        var processInfo = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]

        guard sysctl(&mib, u_int(mib.count), &processInfo, &size, nil, 0) == 0 else {
            return nil
        }
        return processInfo.kp_proc.p_flag
    }
}

/// A wrapper around sysctl for testability.
@_spi(Private) @objc public class SentrySysctl: NSObject, SentryDebuggerStatusProvider {
    
    private let objcHelper = SentrySysctlObjC()
    private let debuggerStatusProvider = SentryDefaultDebuggerStatusProvider()

    var isBeingTraced: Bool {
        debuggerStatusProvider.isBeingTraced
    }
    
    /// Returns the time the system was booted with a precision of microseconds.
    ///
    /// @warning We must not send this information off device because Apple forbids that.
    /// We are allowed send the amount of time that has elapsed between events that occurred within the
    /// app though. For more information see
    /// https://developer.apple.com/documentation/bundleresources/privacy_manifest_files/describing_use_of_required_reason_api#4278394.
    @objc public var systemBootTimestamp: Date {
        objcHelper.systemBootTimestamp
    }
    
    @objc public var processStartTimestamp: Date {
        objcHelper.processStartTimestamp
    }
    
    /// The system time that the process started, as measured in @c SentrySysctl.load, essentially the
    /// earliest time we can record a system timestamp, which is the number of nanoseconds since the
    /// device booted, which is why we can't simply convert @c processStartTimestamp to the nanosecond
    /// representation of its @c timeIntervalSinceReferenceDate .
    @objc public var runtimeInitSystemTimestamp: UInt64 {
        objcHelper.runtimeInitSystemTimestamp
    }
    
    @objc public var runtimeInitTimestamp: Date {
        objcHelper.runtimeInitTimestamp
    }
    
    @objc public var moduleInitializationTimestamp: Date {
        objcHelper.moduleInitializationTimestamp
    }
}
// swiftlint:enable missing_docs
