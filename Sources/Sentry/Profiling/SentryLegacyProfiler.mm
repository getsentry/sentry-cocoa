#import "SentryLegacyProfiler.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryLog.h"
#    import "SentryMetricProfiler.h"
#    import "SentryProfiledTracerConcurrency.h"
#    import "SentryProfiler+Private.h"
#    include <mutex>

#    pragma mark - Private

namespace {
/** @warning: Must be used from a synchronized context. */
std::mutex _unsafe_gLegacyProfilerLock;

/** @warning: Must be used from a synchronized context. */
SentryProfiler *_Nullable _unsafe_gLegacyProfiler;

/** @warning: Must be called from a synchronized context. */
BOOL
_unsafe_isRunning(void)
{
    return _unsafe_gLegacyProfiler != nil && [_unsafe_gLegacyProfiler isRunning];
}
} // namespace

@implementation SentryLegacyProfiler

#    pragma mark - Public

+ (BOOL)startWithTracer:(SentryId *)traceId
{
    std::lock_guard<std::mutex> l(_unsafe_gLegacyProfilerLock);

    if (_unsafe_isRunning()) {
        SENTRY_LOG_DEBUG(@"A legacy profiler is already running.");
        sentry_trackProfilerForTracer(_unsafe_gLegacyProfiler, traceId);
        // record a new metric sample for every concurrent span start
        [_unsafe_gLegacyProfiler.metricProfiler recordMetrics];
        return YES;
    }

    _unsafe_gLegacyProfiler = [[SentryProfiler alloc] initWithMode:SentryProfilerModeLegacy];
    if (_unsafe_gLegacyProfiler == nil) {
        SENTRY_LOG_WARN(@"Legacy profiler was unable to be initialized, will not proceed.");
        return NO;
    }

    sentry_trackProfilerForTracer(_unsafe_gLegacyProfiler, traceId);
    return YES;
}

+ (BOOL)isCurrentlyProfiling
{
    std::lock_guard<std::mutex> l(_unsafe_gLegacyProfilerLock);
    return [_unsafe_gLegacyProfiler isRunning];
}

+ (void)recordMetrics
{
    std::lock_guard<std::mutex> l(_unsafe_gLegacyProfilerLock);
    if (!_unsafe_isRunning()) {
        SENTRY_LOG_DEBUG(@"No legacy profiler is currently running.");
        return;
    }

    [_unsafe_gLegacyProfiler.metricProfiler recordMetrics];
}

#    pragma mark - Testing helpers

#    if defined(TEST) || defined(TESTCI) || defined(DEBUG)
+ (SentryProfiler *_Nullable)getCurrentProfiler
{
    return _unsafe_gLegacyProfiler;
}

+ (void)resetConcurrencyTracking
{
    sentry_resetConcurrencyTracking();
}

+ (NSUInteger)currentProfiledTracers
{
    return sentry_currentProfiledTracers();
}
#    endif // defined(TEST) || defined(TESTCI) || defined(DEBUG)

@end

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
