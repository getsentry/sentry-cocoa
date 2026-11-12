#import "SentryProfiledTracerConcurrency.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryContinuousProfiler.h"
#    import "SentryInternalDefines.h"
#    import "SentryMetricProfiler.h"
#    import "SentryProfiler+Private.h"
#    import "SentryProfilingLog.h"
#    include <mutex>

#    import "SentryInternalDefines.h"
#    import "SentryProfiledTracerConcurrency.h"
#    import "SentryProfiler+Private.h"
#    import "SentryProfilerSDKAdapter.h"
#    import "SentryTraceProfiler.h"

/**
 * a mapping of profilers to the number of tracers that started them that are still in-flight and
 * will need to query them for their profiling data when they finish. this helps resolve the
 * incongruity between the different timeout durations between tracers (500s) and profilers (30s),
 * where a transaction may start a profiler that then times out, and then a new transaction starts a
 * new profiler, and we must keep the aborted one around until its associated transaction finishes.
 */
static NSMutableDictionary</* SentryProfiler.profileId */ SentryProfilingId *,
    /* number of in-flight tracers */ NSNumber *> *_gProfilersToTracers;

/** provided for fast access to a profiler given a tracer */
static NSMutableDictionary</* SentryTracer.internalTraceId */ SentryProfilingId *, SentryProfiler *>
    *_gTracersToProfilers;

/** Continuous roots tracked independently from legacy/hybrid trace-profiler references. */
static NSMutableSet<SentryProfilingId *> *_gInFlightRootSpanIds;

namespace {

std::mutex _gStateLock;

/**
 * Remove a profiler from tracking given the id of the tracer it's associated with.
 * @warning Must be called from a synchronized context.
 */
void
_unsafe_cleanUpTraceProfiler(SentryProfiler *profiler, SentryProfilingId *tracerKey)
{
    const auto profilerKey = profiler.profilerId;
    [_gTracersToProfilers removeObjectForKey:tracerKey];
    _gProfilersToTracers[profilerKey] = @(_gProfilersToTracers[profilerKey].unsignedIntValue - 1);
    const auto remainingTracers = [_gProfilersToTracers[profilerKey] unsignedIntValue];
    if (remainingTracers > 0) {
        SENTRY_PROFILING_LOG_DEBUG(
            @"Waiting on %lu tracers to finish.", (unsigned long)remainingTracers);
        return;
    }

    [_gProfilersToTracers removeObjectForKey:profilerKey];
    [profiler stopForReason:SentryProfilerTruncationReasonNormal];
}

/**
 * Release the owning root's reference and stop continuous profiler if there are none left.
 * @warning Must be called from a synchronized context.
 */
void
_unsafe_cleanUpContinuousProfilerV2(SentryProfilingId *profilerReferenceId)
{
    const auto tracerKey = profilerReferenceId;
    if (![_gInFlightRootSpanIds containsObject:tracerKey]) {
        return;
    }
    [_gInFlightRootSpanIds removeObject:tracerKey];

    if (_gInFlightRootSpanIds.count == 0) {
        SENTRY_PROFILING_LOG_DEBUG(@"Last root span ended, stopping profiler.");
        [SentryContinuousProfiler stop];
    } else {
        SENTRY_PROFILING_LOG_DEBUG(
            @"Waiting for remaining root spans to finish before stopping profiler.");
    }
}

void
sentry_trackRootSpanForContinuousProfilerV2(SentryProfilingId *profilerReferenceId)
{
    std::lock_guard<std::mutex> l(_gStateLock);

    // Backgrounding stops the sampler without ending its in-flight root spans.
    [SentryContinuousProfiler start];
    if (_gInFlightRootSpanIds == nil) {
        _gInFlightRootSpanIds = [NSMutableSet<SentryProfilingId *> set];
    }
    [_gInFlightRootSpanIds addObject:profilerReferenceId];
}

void
sentry_stopTrackingRootSpanForContinuousProfilerV2(SentryProfilingId *profilerReferenceId)
{
    std::lock_guard<std::mutex> l(_gStateLock);
    _unsafe_cleanUpContinuousProfilerV2(profilerReferenceId);
}

} // namespace

void
sentry_finishContinuousProfileForTrace(SentryProfilingId *profilerReferenceId)
{
    sentry_stopTrackingRootSpanForContinuousProfilerV2(profilerReferenceId);
}

void
sentry_trackTransactionProfilerForTrace(
    SentryProfiler *profiler, SentryProfilingId *internalTraceId)
{
    std::lock_guard<std::mutex> l(_gStateLock);

    const auto profilerKey = profiler.profilerId;
    const auto tracerKey = internalTraceId;

    SENTRY_PROFILING_LOG_DEBUG(
        @"Tracking relationship between profiler id %@ and tracer id %@", profilerKey, tracerKey);

    if ((_gProfilersToTracers == nil) != (_gTracersToProfilers == nil)) {
        SENTRY_PROFILING_LOG_WARN(@"Both structures must be initialized simultaneously.");
        NSCAssert(NO, @"Both structures must be initialized simultaneously.");
    }

    if (_gProfilersToTracers == nil) {
        _gProfilersToTracers =
            [NSMutableDictionary</* SentryProfiler.profileId */ SentryProfilingId *,
                /* number of in-flight tracers */ NSNumber *>
                dictionary];
        _gTracersToProfilers =
            [NSMutableDictionary</* SentryTracer.internalTraceId */ SentryProfilingId *,
                SentryProfiler *>
                dictionary];
    }

    _gProfilersToTracers[profilerKey] = @(_gProfilersToTracers[profilerKey].unsignedIntValue + 1);
    _gTracersToProfilers[tracerKey] = profiler;
}

void
sentry_discardProfilerCorrelatedToTrace(SentryProfilingId *internalTraceId)
{
    std::lock_guard<std::mutex> l(_gStateLock);

    // Root ownership survives background cleanup even when the sampler is stopped.
    if (internalTraceId != nil && [_gInFlightRootSpanIds containsObject:internalTraceId]) {
        SENTRY_PROFILING_LOG_DEBUG(
            @"Stopping tracking discarded tracer with profileReferenceId %@", internalTraceId);
        _unsafe_cleanUpContinuousProfilerV2(internalTraceId);
    } else if (internalTraceId != nil) {

        if (_gTracersToProfilers == nil) {
            SENTRY_PROFILING_LOG_ERROR(
                @"Tracer to profiler should have already been initialized by the "
                @"time they are being queried");
        }

        const auto tracerKey = internalTraceId;
        const auto profiler = _gTracersToProfilers[tracerKey];

        if (profiler == nil) {
            return;
        }

        _unsafe_cleanUpTraceProfiler(profiler, tracerKey);

#    if SENTRY_HAS_UIKIT
        if (_gProfilersToTracers == nil) {
            SENTRY_PROFILING_LOG_ERROR(@"Profiler to tracer structure should have already been "
                                       @"initialized by the time they are being queried");
        }
        if (_gProfilersToTracers.count == 0) {
            [SentryProfilerSDKAdapter.shared resetProfilingTimestamps];
        }
#    endif // SENTRY_HAS_UIKIT
    }
}

SentryProfiler *_Nullable sentry_profilerForFinishedTracer(SentryProfilingId *internalTraceId)
{
    std::lock_guard<std::mutex> l(_gStateLock);

    if (_gTracersToProfilers == nil || _gProfilersToTracers == nil) {
        SENTRY_PROFILING_LOG_ERROR(
            @"Structures should have already been initialized by the time they are being queried");
        return nil;
    }

    const auto tracerKey = internalTraceId;
    const auto profiler = _gTracersToProfilers[tracerKey];

    if (profiler == nil) {
        SENTRY_PROFILING_LOG_ERROR(
            @"Expected a profiler to be associated with tracer id %@.", tracerKey);
        return nil;
    }

    _unsafe_cleanUpTraceProfiler(profiler, tracerKey);

#    if SENTRY_HAS_UIKIT
    profiler.screenFrameData = [SentryProfilerSDKAdapter.shared copyFrameMeasurements];
    SENTRY_PROFILING_LOG_DEBUG(
        @"Grabbing copy of frames tracker screen frames data to attach to profiler: %@.",
        profiler.screenFrameData);
    if (_gProfilersToTracers.count == 0) {
        [SentryProfilerSDKAdapter.shared resetProfilingTimestamps];
    }
#    endif // SENTRY_HAS_UIKIT

    return profiler;
}

SentryProfilingId *_Nullable sentry_startProfilerForTrace(
    SentryProfilingTraceDecision decision, SentryProfilingId *traceID)
{
    if (decision == SentryProfilingTraceDecisionContinuous) {
        SentryProfilingId *profilerReferenceId = [[SentryProfilingId alloc] init];
        SENTRY_PROFILING_LOG_DEBUG(
            @"Starting continuous profiler for root span tracer with profilerReferenceId %@",
            profilerReferenceId);
        sentry_trackRootSpanForContinuousProfilerV2(profilerReferenceId);
        return profilerReferenceId;
    }
    if (decision == SentryProfilingTraceDecisionTransaction) {
        SentryProfilingId *internalID = [[SentryProfilingId alloc] init];
        if ([SentryTraceProfiler startWithTracer:internalID]) {
            SENTRY_PROFILING_LOG_DEBUG(
                @"Started profiler for trace %@ with internal id %@", traceID, internalID);
            return internalID;
        }
    }
    return nil;
}

#    if defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)
void
sentry_resetConcurrencyTracking()
{
    std::lock_guard<std::mutex> l(_gStateLock);
    [_gTracersToProfilers removeAllObjects];
    [_gProfilersToTracers removeAllObjects];
    [_gInFlightRootSpanIds removeAllObjects];
}

NSUInteger
sentry_currentProfiledTracers()
{
    std::lock_guard<std::mutex> l(_gStateLock);
    return [_gTracersToProfilers count];
}
#    endif // defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
