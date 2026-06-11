// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate
import Foundation

#if SENTRY_TARGET_PROFILING_SUPPORTED

/// APIs intended for Sentry hybrid SDKs (React Native, Flutter, .NET, Unity).
///
/// These methods are public for consumption by wrapper SDKs that bridge
/// between native and managed runtimes. They may change, be renamed,
/// or be removed in any minor release without prior deprecation.
///
/// App developers: prefer the standard `SentrySDK` API surface instead.
@_spi(Private) public final class SentryInternalProfilingApi {

    /// Starts a profiler session associated with the given trace ID.
    /// - Returns: The system time when the profiler session started.
    @discardableResult
    public func start(for traceId: SentryId) -> UInt64 {
        PrivateSentrySDKOnly.startProfiler(forTrace: traceId)
    }

    /// Collects profiler session data between two system timestamps
    /// for the given trace ID. This also discards the profiler.
    /// - Returns: The profile data dictionary, or `nil` if collection failed.
    public func collect(between startSystemTime: UInt64, and endSystemTime: UInt64, for traceId: SentryId) -> [String: Any]? {
        PrivateSentrySDKOnly.collectProfile(between: startSystemTime, and: endSystemTime, forTrace: traceId) as? [String: Any]
    }

    /// Discards profiler session data for the given trace ID.
    /// Only needed if you haven't collected the profile and don't intend to.
    public func discard(for traceId: SentryId) {
        PrivateSentrySDKOnly.discardProfiler(forTrace: traceId)
    }
}

#endif
// swiftlint:enable missing_docs
