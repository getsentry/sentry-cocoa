// swiftlint:disable missing_docs
internal import _SentryPrivate
import Foundation

#if !(os(watchOS) || os(tvOS) || os(visionOS))

/// Provides profiling operations for hybrid SDKs.
public struct SentryInternalProfilingApi {

    init() {}

    /// Starts a profiler session for the given trace ID.
    /// Returns the system time when the profiler session started.
    public func start(for traceId: SentryId) -> UInt64 {
        let startSystemTime = SentryDependencyContainer.sharedInstance().dateProvider.systemTime()
        SentryTraceProfiler.start(withTracer: traceId)
        return startSystemTime
    }

    /// Collects profiler data between the given system times for the trace.
    /// This also discards the profiler. Returns `nil` if no data is available.
    public func collect(between startTime: UInt64, and endTime: UInt64, for traceId: SentryId) -> [String: Any]? {
        SentryProfileCollector.collectProfileBetween(startTime, and: endTime, forTrace: traceId) as? [String: Any]
    }

    /// Discards the profiler session for the given trace ID without collecting data.
    public func discard(for traceId: SentryId) {
        sentry_discardProfilerCorrelatedToTrace(traceId, SentrySDKInternal.currentHub())
    }
}

#endif
// swiftlint:enable missing_docs
