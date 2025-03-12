@_implementationOnly import _SentryPrivate
import Foundation

/// An object containing configuration for the Sentry profiler.
/// - note: Profiling is automatically disabled if a thread sanitizer is attached. 
@objcMembers
public class SentryProfileOptions: NSObject {
    /// Different modes for starting and stopping the profiler.
    @objc public enum SentryProfileLifecycle: Int {
        /// Profiling is controlled manually, and is independent of transactions & spans. Developers
        /// must `SentrySDK.startProfileSession()` and `SentrySDK.stopProfileSession()` to control
        /// the lifecycle of the profiler. If the session is sampled,
        /// `SentrySDK.startProfileSession()` will always start profiling.
        /// - note: Profiling is automatically disabled if a thread sanitizer is attached.
        case manual
        
        /// Profiling is automatically started when there is at least 1 active root span, and
        /// automatically stopped when there are 0 root spans.
        /// - note: This mode only works if tracing is enabled.
        /// - note: Profiling respects both `SentryProfileOptions.profileSessionSampleRate` and
        /// the existing sampling configuration for tracing
        /// (`SentryOptions.tracesSampleRate`/`SentryOptions.tracesSampler`). Sampling will be
        /// re-evaluated on a per root span basis.
        /// - note: If there are multiple overlapping root spans, where some are sampled and some or
        /// not, profiling will continue until the end of the last sampled root span. Profiling data
        /// will not be linked with spans that are not sampled.
        /// - note: Profiling is automatically disabled if a thread sanitizer is attached.
        case trace
    }
    
    /// The mode to use for starting and stopping the profiler, either manually or automatically.
    /// - note: Default: `SentryProfileLifecycleManual`.
    /// - note: Profiling is automatically disabled if a thread sanitizer is attached.
    public var lifecycle: SentryProfileLifecycle = .manual
    
    /// The % of user sessions in which to enable profiling.
    /// - note: Whether or not the session is sampled is determined once, when the SDK is initially
    /// configured.
    /// - note: If either `SentryOptions.profilesSampleRate` or `SentryOptions.profilesSampler` are
    /// set to a non-nil value such that transaction-based profiling is being used, then setting
    /// this property has no effect, and neither do `SentrySDK.startProfileSession()` or
    /// `SentrySDK.stopProfileSession()`.
    /// - note: The profiling session starts when a new user session begins, and stops when the user
    /// session ends. Backgrounding and foregrounding the app starts a new user session and sampling
    /// is re-evaluated. If there is no active trace when the app is backgrounded, profiling stops
    /// before the app backgrounds. If there is an active trace and profiling is in-flight when the
    /// app is foregrounded again, the same profiling session should continue until the last root
    /// span in that trace finishes — this means that the re-evaluated sample rate does not actually
    /// take effect until the profiler is started again.
    public var sessionSampleRate: Float = 0
}
