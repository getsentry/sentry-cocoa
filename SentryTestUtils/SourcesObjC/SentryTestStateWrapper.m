#import "SentryTestStateWrapper.h"

#import "SentryPerformanceTracker.h"
#import "SentryProfilingConditionals.h"
#import "SentrySDKInternal.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED
#    import "SentryContinuousProfiler.h"
#    import "SentryFileManagerHelper.h"
#    import "SentryLaunchProfiling.h"
#    import "SentryProfiledTracerConcurrency.h"
#    import "SentryProfiler+Private.h"
#    import "SentryTraceProfiler.h"
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

@interface SentrySDKInternal (SentryTestStateWrapper)

+ (void)setCurrentHub:(nullable SentryHubInternal *)hub;

@end

@interface SentryPerformanceTracker (SentryTestStateWrapper)

- (void)clear;

@end

#if SENTRY_TARGET_PROFILING_SUPPORTED
#    if defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)
@interface SentryTraceProfiler (SentryTestStateWrapper)

+ (nullable SentryProfiler *)getCurrentProfiler;

@end
#    endif // defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)

@interface SentryContinuousProfiler (SentryTestStateWrapper)

+ (void)stopTimerAndCleanup;

@end
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

void
wrapper_setCurrentHub(SentryHubInternal *_Nullable hub)
{
    [SentrySDKInternal setCurrentHub:hub];
}

void
wrapper_clearPerformanceTracker(void)
{
    [SentryPerformanceTracker.shared clear];
}

void
wrapper_resetProfilingState(void)
{
#if SENTRY_TARGET_PROFILING_SUPPORTED
    extern NSTimer *_Nullable _sentry_threadUnsafe_traceProfileTimeoutTimer;

    _sentry_threadUnsafe_traceProfileTimeoutTimer = nil;

#    if defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)
    [[SentryTraceProfiler getCurrentProfiler] stopForReason:SentryProfilerTruncationReasonNormal];
    sentry_resetConcurrencyTracking();
#    endif // defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)

    removeAppLaunchProfilingConfigFile();
    sentry_stopAndDiscardLaunchProfileTracer(nil);

    if ([SentryContinuousProfiler isCurrentlyProfiling]) {
        [SentryContinuousProfiler stopTimerAndCleanup];
    }
#endif // SENTRY_TARGET_PROFILING_SUPPORTED
}
