// This is a separate header extension that's able to be included into the Swift bridging header for
// the tests. SentryProfiler+Test.h contains C++ symbols which are not able to be exported to Swift.

#include "SentryProfiler.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

@interface
SentryProfiler ()

/**
 * By default, the profiler will use an instance of @c SentrySystemWrapper. Use this method to swap
 * out for a different instance, like @c TestSentrySystemWrapper.
 */
+ (void)useSystemWrapper:(SentrySystemWrapper *)systemWrapper NS_SWIFT_NAME(useSystemWrapper(_:));

/**
 * By default, the profiler will use an instance of @c SentrySystemWrapper. Use this method to swap
 * out for a different instance, like @c TestSentrySystemWrapper.
 */
+ (void)useProcessInfoWrapper:(SentryNSProcessInfoWrapper *)processInfoWrapper
    NS_SWIFT_NAME(useProcessInfoWrapper(_:));

+ (void)useTimerWrapper:(SentryNSTimerWrapper *)timerWrapper NS_SWIFT_NAME(useTimerWrapper(_:));

#    if SENTRY_HAS_UIKIT
+ (void)useFramesTracker:(SentryFramesTracker *)framesTracker NS_SWIFT_NAME(useFramesTracker(_:));
#    endif // SENTRY_HAS_UIKIT

@end

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
