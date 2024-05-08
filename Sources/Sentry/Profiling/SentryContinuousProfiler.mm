#import "SentryContinuousProfiler.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryDependencyContainer.h"
#    import "SentryLog.h"
#    import "SentryMetricProfiler.h"
#    import "SentryNSTimerFactory.h"
#    import "SentryProfiler+Private.h"
#    import "SentryProfilerSerialization.h"
#    import "SentryProfilerState.h"
#    import "SentrySDK+Private.h"
#    import "SentrySwift.h"
#    import "SentryThreadWrapper.h"
#    include <mutex>

#    pragma mark - Private

namespace {
/** @warning: Must be used from a synchronized context. */
std::mutex _threadUnsafe_gContinuousProfilerLock;

/** @warning: Must be used from a synchronized context. */
SentryProfiler *_Nullable _threadUnsafe_gContinuousCurrentProfiler;

NSTimer *_Nullable _chunkTimer;

void
disableTimer()
{
    [_chunkTimer invalidate];
    _chunkTimer = nil;
}
} // namespace

@implementation SentryContinuousProfiler

#    pragma mark - Public

+ (void)start
{
    {
        std::lock_guard<std::mutex> l(_threadUnsafe_gContinuousProfilerLock);

        if ([_threadUnsafe_gContinuousCurrentProfiler isRunning]) {
            SENTRY_LOG_DEBUG(@"A continuous profiler is already running.");
            return;
        }

        if (!(_threadUnsafe_gContinuousCurrentProfiler =
                    [[SentryProfiler alloc] initWithMode:SentryProfilerModeContinuous])) {
            SENTRY_LOG_WARN(@"Continuous profiler was unable to be initialized.");
            return;
        }
    }

    [self scheduleTimer];
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

    disableTimer();

    [_threadUnsafe_gContinuousCurrentProfiler stopForReason:SentryProfilerTruncationReasonNormal];
}

#    pragma mark - Private

/**
 * Schedule a timeout timer on the main thread.
 * @warning from NSTimer.h: Timers scheduled in an async context may never fire.
 */
+ (void)scheduleTimer
{
    [SentryThreadWrapper onMainThread:^{
        std::lock_guard<std::mutex> l(_threadUnsafe_gContinuousProfilerLock);
        if (_chunkTimer != nil) {
            return;
        }

        _chunkTimer = [SentryDependencyContainer.sharedInstance.timerFactory
            scheduledTimerWithTimeInterval:kSentryProfilerChunkExpirationInterval
                                    target:self
                                  selector:@selector(timerExpired)
                                  userInfo:nil
                                   repeats:YES];
    }];
}

+ (void)timerExpired
{
    {
        std::lock_guard<std::mutex> l(_threadUnsafe_gContinuousProfilerLock);
        if (![_threadUnsafe_gContinuousCurrentProfiler isRunning]) {
            SENTRY_LOG_WARN(@"Current profiler is not running. Sending whatever data it has left "
                            @"and disabling the timer from running again.");
            disableTimer();
        }
    }

    [self transmitChunkEnvelope];
}

+ (void)transmitChunkEnvelope
{
    std::lock_guard<std::mutex> l(_threadUnsafe_gContinuousProfilerLock);

    const auto profiler = _threadUnsafe_gContinuousCurrentProfiler;
    const auto stateCopy = [profiler.state copyProfilingData];
    const auto startSystemTime = profiler.continuousChunkStartSystemTime;
    const auto endSystemTime = SentryDependencyContainer.sharedInstance.dateProvider.systemTime;
    profiler.continuousChunkStartSystemTime = endSystemTime + 1;
    [profiler.state clear]; // !!!: profile this to see if it takes longer than one sample duration
                            // length: ~9ms

    const auto envelope = sentry_continuousProfileChunkEnvelope(
        startSystemTime, endSystemTime, stateCopy, profiler.profilerId,
        [profiler.metricProfiler serializeBetween:startSystemTime and:endSystemTime]
#    if SENTRY_HAS_UIKIT
        ,
        profiler.screenFrameData
#    endif // SENTRY_HAS_UIKIT
    );
    [SentrySDK captureEnvelope:envelope];
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
