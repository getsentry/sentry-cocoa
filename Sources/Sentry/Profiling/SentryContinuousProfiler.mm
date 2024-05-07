#import "SentryContinuousProfiler.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryLog.h"
#    import "SentryProfiler+Private.h"
#    include <mutex>

#    pragma mark - Private

namespace {
/** @warning: Must be used from a synchronized context. */
std::mutex _threadUnsafe_gContinuousProfilerLock;

/** @warning: Must be used from a synchronized context. */
SentryProfiler *_Nullable _threadUnsafe_gContinuousCurrentProfiler;
} // namespace

@implementation SentryContinuousProfiler

#    pragma mark - Public

+ (void)start
{
    std::lock_guard<std::mutex> l(_threadUnsafe_gContinuousProfilerLock);

    if ([_threadUnsafe_gContinuousCurrentProfiler isRunning]) {
        SENTRY_LOG_DEBUG(@"A continuous profiler is already running.");
        return;
    }

    if (!(_threadUnsafe_gContinuousCurrentProfiler =
                [[SentryProfiler alloc] initWithMode:SentryProfilerModeContinuous])) {
        SENTRY_LOG_WARN(@"Continuous profiler was unable to be initialized.");
    }
}

+ (BOOL)isCurrentlyProfiling
{
    std::lock_guard<std::mutex> l(_threadUnsafe_gContinuousProfilerLock);
    return [_threadUnsafe_gContinuousCurrentProfiler isRunning];
}

+ (void)stop
{
    std::lock_guard<std::mutex> l(_threadUnsafe_gContinuousProfilerLock);

    if (![_threadUnsafe_gContinuousCurrentProfiler isRunning]) {
        SENTRY_LOG_DEBUG(@"No continuous profiler is currently running.");
        return;
    }

    [_threadUnsafe_gContinuousCurrentProfiler stopForReason:SentryProfilerTruncationReasonNormal];
}

#    pragma mark - Testing

#    if defined(TEST) || defined(TESTCI) || defined(DEBUG)
+ (nullable SentryProfiler *)profiler
{
    std::lock_guard<std::mutex> l(_threadUnsafe_gContinuousProfilerLock);
    return _threadUnsafe_gContinuousCurrentProfiler;
}
#    endif // defined(TEST) || defined(TESTCI) || defined(DEBUG)

@end

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
