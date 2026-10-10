#import "Utils/SentryTestState.h"
#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED
#    import "SentryFileManagerHelper.h"
#    import "SentryLaunchProfiling.h"
#    import "SentryProfiledTracerConcurrency.h"
#    import "SentryProfiler+Private.h"
#    import "Wrappers/SentryContinuousProfilerWrapper.h"
#    import "Wrappers/SentryTraceProfilerWrapper.h"
#endif

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
