#import "SentryContinuousProfiler.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryLog.h"
#    import "SentryProfiler+Private.h"
#    include <mutex>

#    pragma mark - Private

namespace {
/** @warning: Must be used from a synchronized context. */
std::mutex _unsafe_gContinuousProfilerLock;

/** @warning: Must be used from a synchronized context. */
SentryProfiler *_Nullable _unsafe_gContinuousCurrentProfiler;

/** @warning: Must be called from a synchronized context. */
BOOL
_unsafe_isRunning(void)
{
    return _unsafe_gContinuousCurrentProfiler != nil &&
        [_unsafe_gContinuousCurrentProfiler isRunning];
}
} // namespace

@implementation SentryContinuousProfiler

#    pragma mark - Public

+ (void)start
{
    std::lock_guard<std::mutex> l(_unsafe_gContinuousProfilerLock);

    if (_unsafe_isRunning()) {
        SENTRY_LOG_DEBUG(@"A continuous profiler is already running.");
        return;
    }

    if (!(_unsafe_gContinuousCurrentProfiler =
                [[SentryProfiler alloc] initWithMode:SentryProfilerModeContinuous])) {
        SENTRY_LOG_WARN(@"Continuous profiler was unable to be initialized.");
    }
}

+ (BOOL)isCurrentlyProfiling
{
    std::lock_guard<std::mutex> l(_unsafe_gContinuousProfilerLock);
    return _unsafe_isRunning();
}

+ (void)stop
{
    std::lock_guard<std::mutex> l(_unsafe_gContinuousProfilerLock);

    if (!_unsafe_isRunning()) {
        SENTRY_LOG_DEBUG(@"No continuous profiler is currently running.");
        return;
    }

    [_unsafe_gContinuousCurrentProfiler stopForReason:SentryProfilerTruncationReasonNormal];
}

#    pragma mark - Testing

#    if defined(TEST) || defined(TESTCI) || defined(DEBUG)
+ (nullable SentryProfiler *)profiler
{
    std::lock_guard<std::mutex> l(_unsafe_gContinuousProfilerLock);
    return _unsafe_gContinuousCurrentProfiler;
}
#    endif // defined(TEST) || defined(TESTCI) || defined(DEBUG)

@end

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
