@_implementationOnly import _SentryPrivate
import Foundation

/// An object containing configuration for the Sentry profiler.
@objcMembers
public class SentryProfileOptions: NSObject {
    /// Different modes for starting and stopping the profiler.
    @objc public enum SentryProfileLifecycle: Int {
        /// Profiling is controlled manually, and is independent of transactions & spans. Developers
        /// must `SentrySDK.startProfileSession()` and `SentrySDK.stopProfileSession()` to control
        /// the lifecycle of the profiler. If the session is sampled,
        /// `SentrySDK.startProfileSession()` will always start profiling.
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
        case trace
    }
    
    /// The mode to use for starting and stopping the profiler, either manually or automatically.
    public var lifecycle: SentryProfileLifecycle = .manual
    
}
