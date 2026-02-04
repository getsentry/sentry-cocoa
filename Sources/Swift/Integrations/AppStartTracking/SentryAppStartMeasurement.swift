@_implementationOnly import _SentryPrivate
import Foundation

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

/// The type of the app start.
@_spi(Private)
@objc
public enum SentryAppStartType: UInt {
    /// A warm start occurs when the app was recently terminated and is partially in memory.
    case warm
    /// A cold start occurs after a device reboot when the app is not in memory.
    case cold
    /// The start type could not be determined.
    case unknown
}

/// Helper class for converting SentryAppStartType to string.
/// This is needed for serialization in HybridSDKs.
@_spi(Private)
@objc
public final class SentryAppStartTypeToString: NSObject {
    
    /// Converts a `SentryAppStartType` to its string representation.
    @objc
    public static func convert(_ type: SentryAppStartType) -> String {
        switch type {
        case .warm:
            return "warm"
        case .cold:
            return "cold"
        case .unknown:
            return "unknown"
        }
    }
}

/// Holds the information about the app start.
/// - warning: This feature is not available in `DebugWithoutUIKit` and `ReleaseWithoutUIKit`
/// configurations even when targeting iOS or tvOS platforms.
@_spi(Private)
@objc
public final class SentryAppStartMeasurement: NSObject {
    
    /// The type of the app start.
    @objc public let type: SentryAppStartType
    
    /// Whether the app was prewarmed by the OS before the user opened it.
    @objc public let isPreWarmed: Bool
    
    /// How long the app start took. From appStartTimestamp to when the SDK creates the
    /// AppStartMeasurement, which is done when the first CADisplayLink callback is received.
    @objc public let duration: TimeInterval
    
    /// The timestamp when the app started, which is the process start timestamp and for prewarmed app
    /// starts the moduleInitializationTimestamp.
    @objc public let appStartTimestamp: Date
    
    /// Similar to `appStartTimestamp`, but in number of nanoseconds, and retrieved with
    /// `clock_gettime_nsec_np` / `mach_absolute_time` if measured from module initialization time.
    @objc public let runtimeInitSystemTimestamp: UInt64
    
    /// When the runtime was initialized / when SentryAppStartTracker is added to the Objective-C runtime
    @objc public let runtimeInitTimestamp: Date
    
    /// When application main function is called.
    @objc public let moduleInitializationTimestamp: Date
    
    /// When the SentrySDK start method is called.
    @objc public let sdkStartTimestamp: Date
    
    /// When OS posts UIApplicationDidFinishLaunchingNotification.
    @objc public let didFinishLaunchingTimestamp: Date
    
    /// Initializes SentryAppStartMeasurement with the given parameters.
    init(
        type: SentryAppStartType,
        isPreWarmed: Bool,
        appStartTimestamp: Date,
        runtimeInitSystemTimestamp: UInt64,
        duration: TimeInterval,
        runtimeInitTimestamp: Date,
        moduleInitializationTimestamp: Date,
        sdkStartTimestamp: Date,
        didFinishLaunchingTimestamp: Date
    ) {
        self.type = type
        self.isPreWarmed = isPreWarmed
        self.appStartTimestamp = appStartTimestamp
        self.runtimeInitSystemTimestamp = runtimeInitSystemTimestamp
        self.duration = duration
        self.runtimeInitTimestamp = runtimeInitTimestamp
        self.moduleInitializationTimestamp = moduleInitializationTimestamp
        self.sdkStartTimestamp = sdkStartTimestamp
        self.didFinishLaunchingTimestamp = didFinishLaunchingTimestamp
    }
}

#endif // (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
