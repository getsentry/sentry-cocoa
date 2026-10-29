#import "SentryProfiledTracerConcurrency.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryContinuousProfiler.h"
#    import "SentryInternalDefines.h"
#    import "SentryLogC.h"
#    import "SentryProfiler+Private.h"
#    include <mutex>

#    import "SentryInternalDefines.h"
#    import "SentryProfiledTracerConcurrency.h"
#    import "SentryProfiler+Private.h"
#    import "SentryProfilerSDKAdapter.h"
#    import "SentryProfilingSwiftHelpers.h"
#    import "SentryTraceProfiler.h"

/**
 * a mapping of profilers to the number of tracers that started them that are still in-flight and
 * will need to query them for their profiling data when they finish. this helps resolve the
 * incongruity between the different timeout durations between tracers (500s) and profilers (30s),
 * where a transaction may start a profiler that then times out, and then a new transaction starts a
 * new profiler, and we must keep the aborted one around until its associated transaction finishes.
 */
static NSMutableDictionary</* SentryProfiler.profileId */ NSString *,
    /* number of in-flight tracers */ NSNumber *> *_gProfilersToTracers;

/** provided for fast access to a profiler given a tracer */
static NSMutableDictionary</* SentryTracer.internalTraceId */ NSString *, SentryProfiler *>
    *_gTracersToProfilers;

static unsigned int _gInFlightRootSpans = 0;

namespace {

std::mutex _gStateLock;

/**
 * Remove a profiler from tracking given the id of the tracer it's associated with.
 * @warning Must be called from a synchronized context.
 */
void
_unsafe_cleanUpTraceProfiler(SentryProfiler *profiler, NSString *tracerKey)
{
    const auto profilerKey = sentry_stringFromSentryID(profiler.profilerId);
    [_gTracersToProfilers removeObjectForKey:tracerKey];
    _gProfilersToTracers[profilerKey] = @(_gProfilersToTracers[profilerKey].unsignedIntValue - 1);
    const auto remainingTracers = [_gProfilersToTracers[profilerKey] unsignedIntValue];
    if (remainingTracers > 0) {
        SENTRY_LOG_DEBUG(@"Waiting on %lu tracers to finish.", remainingTracers);
        return;
    }

    [_gProfilersToTracers removeObjectForKey:profilerKey];
    [profiler stopForReason:SentryProfilerTruncationReasonNormal];
}

/**
 * Decrement number of root spans in flight and stop continuous profiler if there are none left.
 * @warning Must be called from a synchronized context.
 */
void
_unsafe_cleanUpContinuousProfilerV2()
{
    if (_gInFlightRootSpans == 0) {
        SENTRY_LOG_ERROR(@"Attemtpted to stop continuous profiler with no root spans in flight.");
    } else {
        _gInFlightRootSpans -= 1;
    }

    if (_gInFlightRootSpans == 0) {
        SENTRY_LOG_DEBUG(@"Last root span ended, stopping profiler.");
        [SentryContinuousProfiler stop];
    } else {
        SENTRY_LOG_DEBUG(@"Waiting for remaining root spans to finish before stopping profiler.");
    }
}

void
sentry_trackRootSpanForContinuousProfilerV2()
{
    std::lock_guard<std::mutex> l(_gStateLock);

    if (![SentryContinuousProfiler isCurrentlyProfiling] && _gInFlightRootSpans != 0) {
        SENTRY_LOG_ERROR(@"Unbalanced tracking of root spans and profiler detected.");
        return;
    }

    [SentryContinuousProfiler start];
    _gInFlightRootSpans += 1;
}

void
sentry_stopTrackingRootSpanForContinuousProfilerV2()
{
    std::lock_guard<std::mutex> l(_gStateLock);
    _unsafe_cleanUpContinuousProfilerV2();
}

} // namespace

void
sentry_finishContinuousProfileForTrace(void)
{
    sentry_stopTrackingRootSpanForContinuousProfilerV2();
}

void
sentry_trackTransactionProfilerForTrace(SentryProfiler *profiler, SentryId *internalTraceId)
{
    std::lock_guard<std::mutex> l(_gStateLock);

    const auto profilerKey = sentry_stringFromSentryID(profiler.profilerId);
    const auto tracerKey = sentry_stringFromSentryID(internalTraceId);

    SENTRY_LOG_DEBUG(
        @"Tracking relationship between profiler id %@ and tracer id %@", profilerKey, tracerKey);

    SENTRY_CASSERT((_gProfilersToTracers == nil && _gTracersToProfilers == nil)
            || (_gProfilersToTracers != nil && _gTracersToProfilers != nil),
        @"Both structures must be initialized simultaneously.");

    if (_gProfilersToTracers == nil) {
        _gProfilersToTracers = [NSMutableDictionary</* SentryProfiler.profileId */ NSString *,
            /* number of in-flight tracers */ NSNumber *>
            dictionary];
        _gTracersToProfilers =
            [NSMutableDictionary</* SentryTracer.internalTraceId */ NSString *, SentryProfiler *>
                dictionary];
    }

    _gProfilersToTracers[profilerKey] = @(_gProfilersToTracers[profilerKey].unsignedIntValue + 1);
    _gTracersToProfilers[tracerKey] = profiler;
}

void
sentry_discardProfilerCorrelatedToTrace(SentryId *internalTraceId)
{
    std::lock_guard<std::mutex> l(_gStateLock);

    if ([SentryContinuousProfiler isCurrentlyProfiling]) {
        SENTRY_LOG_DEBUG(@"Stopping tracking discarded tracer with profileReferenceId %@",
            sentry_stringFromSentryID(internalTraceId));
        _unsafe_cleanUpContinuousProfilerV2();
    } else if (internalTraceId != nil) {

        if (_gTracersToProfilers == nil) {
            SENTRY_LOG_ERROR(@"Tracer to profiler should have already been initialized by the "
                             @"time they are being queried");
        }

        const auto tracerKey = sentry_stringFromSentryID(internalTraceId);
        const auto profiler = _gTracersToProfilers[tracerKey];

        if (profiler == nil) {
            return;
        }

        _unsafe_cleanUpTraceProfiler(profiler, tracerKey);

#    if SENTRY_HAS_UIKIT
        if (_gProfilersToTracers == nil) {
            SENTRY_LOG_ERROR(@"Profiler to tracer structure should have already been "
                             @"initialized by the time they are being queried");
        }
        if (_gProfilersToTracers.count == 0) {
            [SentryProfilerSDKAdapter.shared resetProfilingTimestamps];
        }
#    endif // SENTRY_HAS_UIKIT
    }
}

SentryProfiler *_Nullable sentry_profilerForFinishedTracer(SentryId *internalTraceId)
{
    std::lock_guard<std::mutex> l(_gStateLock);

    if (_gTracersToProfilers == nil || _gProfilersToTracers == nil) {
        SENTRY_LOG_ERROR(
            @"Structures should have already been initialized by the time they are being queried");
        return nil;
    }

    const auto tracerKey = sentry_stringFromSentryID(internalTraceId);
    const auto profiler = _gTracersToProfilers[tracerKey];

    if (profiler == nil) {
        SENTRY_LOG_ERROR(@"Expected a profiler to be associated with tracer id %@.", tracerKey);
        return nil;
    }

    _unsafe_cleanUpTraceProfiler(profiler, tracerKey);

#    if SENTRY_HAS_UIKIT
    profiler.screenFrameData = [SentryProfilerSDKAdapter.shared copyFrameMeasurements];
    SENTRY_LOG_DEBUG(
        @"Grabbing copy of frames tracker screen frames data to attach to profiler: %@.",
        profiler.screenFrameData);
    if (_gProfilersToTracers.count == 0) {
        [SentryProfilerSDKAdapter.shared resetProfilingTimestamps];
    }
#    endif // SENTRY_HAS_UIKIT

    return profiler;
}

SentryId *_Nullable sentry_startProfilerForTrace(
    SentryProfilingTraceDecision decision, SentryTransactionContext *transactionContext)
{
    if (decision == SentryProfilingTraceDecisionContinuous) {
        SentryId *profilerReferenceId = sentry_getSentryId();
        SENTRY_LOG_DEBUG(
            @"Starting continuous profiler for root span tracer with profilerReferenceId %@",
            sentry_stringFromSentryID(profilerReferenceId));
        sentry_trackRootSpanForContinuousProfilerV2();
        return profilerReferenceId;
    }
    if (decision == SentryProfilingTraceDecisionTransaction) {
        SentryId *internalID = sentry_getSentryId();
        if ([SentryTraceProfiler startWithTracer:internalID]) {
            SENTRY_LOG_DEBUG(@"Started profiler for trace %@ with internal id %@",
                sentry_stringFromSentryID(sentry_getTraceID(transactionContext)),
                sentry_stringFromSentryID(internalID));
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
    _gInFlightRootSpans = 0;
}

NSUInteger
sentry_currentProfiledTracers()
{
    std::lock_guard<std::mutex> l(_gStateLock);
    return [_gTracersToProfilers count];
}
#    endif // defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
