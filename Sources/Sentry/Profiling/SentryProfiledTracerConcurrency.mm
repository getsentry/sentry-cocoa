#import "SentryProfiledTracerConcurrency.h"

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
static NSMapTable</* SentryTracer.tracerId */ NSString *, NSHashTable<SentryTracer *> *>
    *_gStrongProfilersToWeakTracers;

/** provided for fast access to a profiler given a tracer */
static NSMapTable</* SentryTracer.tracerId */ NSString *, SentryProfiler *>
    *_gWeakTracersToWeakProfilers;

std::mutex _gStateLock;

void
trackProfilerForTracer(SentryProfiler *profiler, SentryTracer *tracer)
{
    std::lock_guard<std::mutex> l(_gStateLock);

    const auto profilerKey = profiler.profileId.sentryIdString;
    const auto tracerKey = tracer.traceId.sentryIdString;

    SENTRY_LOG_DEBUG(
        @"Tracking relationship between profiler id %@ and tracer id %@", profilerKey, tracerKey);

    SENTRY_CASSERT((_gStrongProfilersToWeakTracers == nil && _gWeakTracersToWeakProfilers == nil)
            || (_gStrongProfilersToWeakTracers != nil && _gWeakTracersToWeakProfilers != nil),
        @"Both structures must be initialized simultaneously.");

    if (_gStrongProfilersToWeakTracers == nil) {
        _gWeakTracersToWeakProfilers =
            [[NSMapTable</* SentryTracer.tracerId */ NSString *, SentryProfiler *> alloc]
                initWithKeyOptions:NSPointerFunctionsStrongMemory
                      valueOptions:NSPointerFunctionsWeakMemory
                          capacity:1];
        _gStrongProfilersToWeakTracers =
            [[NSMapTable</* SentryProfiler.profileId */ NSString *, NSHashTable<SentryTracer *> *>
                alloc] initWithKeyOptions:NSPointerFunctionsWeakMemory
                             valueOptions:NSPointerFunctionsWeakMemory
                                 capacity:1];
        return;
    }

    const auto tracerTable = [_gStrongProfilersToWeakTracers objectForKey:profilerKey];
    if (tracerTable == nil) {
        const auto table = [[NSHashTable alloc] initWithOptions:NSPointerFunctionsWeakMemory
                                                       capacity:1];
        [table addObject:tracer];
        [_gStrongProfilersToWeakTracers setObject:table forKey:profilerKey];
    } else {
        [tracerTable addObject:tracer];
    }

    [_gWeakTracersToWeakProfilers setObject:profiler forKey:tracerKey];
}

void
discardProfilerForTracer(SentryTracer *tracer)
{
    std::lock_guard<std::mutex> l(_gStateLock);

    SENTRY_CASSERT(_gWeakTracersToWeakProfilers != nil && _gStrongProfilersToWeakTracers != nil,
        @"Structures should have already been initialized by the time they are being queried");

    const auto tracerKey = tracer.traceId.sentryIdString;
    const auto profiler = [_gWeakTracersToWeakProfilers objectForKey:tracerKey];

    if (!SENTRY_CASSERT_RETURN(profiler != nil,
            @"Expected a profiler to be associated with tracer id %@.", tracerKey)) {
        return;
    }

    const auto profilerKey = profiler.profileId.sentryIdString;

    [_gWeakTracersToWeakProfilers removeObjectForKey:tracerKey];
    const auto tracerTable = [_gStrongProfilersToWeakTracers objectForKey:profilerKey];
    [tracerTable removeObject:tracer];
    if ([tracerTable count] == 0) {
        [_gStrongProfilersToWeakTracers removeObjectForKey:profilerKey];
        if ([profiler isRunning]) {
            [profiler stopForReason:SentryProfilerTruncationReasonNormal];
        }
    }

#    if SENTRY_HAS_UIKIT
    if (_gStrongProfilersToWeakTracers.count == 0) {
        [SentryDependencyContainer.sharedInstance.framesTracker resetProfilingTimestamps];
    }
#    endif // SENTRY_HAS_UIKIT
}

SentryProfiler *_Nullable profilerForFinishedTracer(SentryTracer *tracer)
{
    std::lock_guard<std::mutex> l(_gStateLock);

    SENTRY_CASSERT(_gWeakTracersToWeakProfilers != nil && _gStrongProfilersToWeakTracers != nil,
        @"Structures should have already been initialized by the time they are being queried");

    const auto tracerKey = tracer.traceId.sentryIdString;
    const auto profiler = [_gWeakTracersToWeakProfilers objectForKey:tracerKey];

    if (!SENTRY_CASSERT_RETURN(profiler != nil,
            @"Expected a profiler to be associated with tracer id %@.", tracerKey)) {
        return nil;
    }

    const auto profilerKey = profiler.profileId.sentryIdString;

    [_gWeakTracersToWeakProfilers removeObjectForKey:tracerKey];
    const auto tracerTable = [_gStrongProfilersToWeakTracers objectForKey:profilerKey];
    [tracerTable removeObject:tracer];
    if ([tracerTable count] == 0) {
        [_gStrongProfilersToWeakTracers removeObjectForKey:profilerKey];
        if ([profiler isRunning]) {
            [profiler stopForReason:SentryProfilerTruncationReasonNormal];
        }
    }

#    if SENTRY_HAS_UIKIT
    profiler._screenFrameData =
        [SentryDependencyContainer.sharedInstance.framesTracker.currentFrames copy];
    if (_gStrongProfilersToWeakTracers.count == 0) {
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
    [_gWeakTracersToWeakProfilers removeAllObjects];
    [_gStrongProfilersToWeakTracers removeAllObjects];
}
#    endif // defined(TEST) || defined(TESTCI)

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
