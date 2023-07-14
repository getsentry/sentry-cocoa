#import "SentryTracerConcurrency.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryId.h"
#    import "SentryInternalDefines.h"
#    import "SentryLog.h"
#    import "SentryProfiler+Private.h"
#    import "SentryTracer.h"
#    include <mutex>

#    if SENTRY_HAS_UIKIT
#        import "SentryDependencyContainer.h"
#        import "SentryFramesTracker.h"
#        import "SentryScreenFrames.h"
#    endif // SENTRY_HAS_UIKIT

/**
 * a mapping of profilers to the tracers that started them that are still in-flight and will need to
 * query them for their profiling data when they finish. this helps resolve the incongruity between
 * the different timeout durations between tracers (500s) and profilers (30s), where a transaction
 * may start a profiler that then times out, and then a new transaction starts a new profiler, and
 * we must keep the aborted one around until its associated transaction finishes.
 */
static NSMutableDictionary</* SentryProfiler.profileId */ NSString *,
    NSMutableSet<SentryTracer *> *> *_gProfilersToTracers;

/** provided for fast access to a profiler given a tracer */
static NSMutableDictionary</* SentryTracer.tracerId */ NSString *, SentryProfiler *>
    *_gTracersToProfilers;

std::mutex _gStateLock;

void
trackProfilerForTracer(SentryProfiler *profiler, SentryTracer *tracer)
{
    std::lock_guard<std::mutex> l(_gStateLock);

    const auto profilerKey = profiler.profileId.sentryIdString;
    const auto tracerKey = tracer.traceId.sentryIdString;

    SENTRY_LOG_DEBUG(
        @"Tracking relationship between profiler id %@ and tracer id %@", profilerKey, tracerKey);

    SENTRY_CASSERT((_gProfilersToTracers == nil && _gTracersToProfilers == nil)
            || (_gProfilersToTracers != nil && _gTracersToProfilers != nil),
        @"Both structures must be initialized simultaneously.");

    if (_gProfilersToTracers == nil) {
        _gProfilersToTracers = [NSMutableDictionary</* SentryProfiler.profileId */ NSString *,
            NSMutableSet<SentryTracer *> *> dictionaryWithObject:[NSMutableSet setWithObject:tracer]
                                                          forKey:profilerKey];
        _gTracersToProfilers =
            [NSMutableDictionary</* SentryTracer.tracerId */ NSString *, SentryProfiler *>
                dictionaryWithObject:profiler
                              forKey:tracerKey];
        return;
    }

    if (_gProfilersToTracers[profilerKey] == nil) {
        _gProfilersToTracers[profilerKey] = [NSMutableSet setWithObject:tracer];
    } else {
        [_gProfilersToTracers[profilerKey] addObject:tracer];
    }

    _gTracersToProfilers[tracerKey] = profiler;
}

SentryProfiler *_Nullable profilerForFinishedTracer(SentryTracer *tracer)
{
    std::lock_guard<std::mutex> l(_gStateLock);

    SENTRY_CASSERT(_gTracersToProfilers != nil && _gProfilersToTracers != nil,
        @"Structures should have already been initialized by the time they are being queried");

    const auto tracerKey = tracer.traceId.sentryIdString;
    const auto profiler = _gTracersToProfilers[tracerKey];

    if (!SENTRY_CASSERT_RETURN(profiler != nil,
            @"Expected a profiler to be associated with tracer id %@.", tracerKey)) {
        return nil;
    }

    const auto profilerKey = profiler.profileId.sentryIdString;

    [_gTracersToProfilers removeObjectForKey:tracerKey];
    [_gProfilersToTracers[profilerKey] removeObject:tracer];
    if ([_gProfilersToTracers[profilerKey] count] == 0) {
        [_gProfilersToTracers removeObjectForKey:profilerKey];
        if ([profiler isRunning]) {
            [profiler stopForReason:SentryProfilerTruncationReasonNormal];
        }
    }

#    if SENTRY_HAS_UIKIT
    profiler._screenFrameData =
        [SentryDependencyContainer.sharedInstance.framesTracker.currentFrames copy];
    if (_gProfilersToTracers.count == 0) {
        [SentryDependencyContainer.sharedInstance.framesTracker resetProfilingTimestamps];
    }
#    endif // SENTRY_HAS_UIKIT

    return profiler;
}

#    if defined(TEST) || defined(TESTCI)
void
resetConcurrencyTracking()
{
    std::lock_guard<std::mutex> l(_gStateLock);
    [_gTracersToProfilers removeAllObjects];
    [_gProfilersToTracers removeAllObjects];
}
#    endif // defined(TEST) || defined(TESTCI)

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
