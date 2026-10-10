#import "SentryDefines.h"
#import "SentryProfilingConditionals.h"
@import _SentryPrivate;

#if SENTRY_TARGET_PROFILING_SUPPORTED
#    import "SentryProfiler+Private.h"

NS_ASSUME_NONNULL_BEGIN

// Erase Swift-owned options only at the Clang boundary; dispatch to the original SDK functions.
FOUNDATION_EXPORT void sentry_test_sdkInitProfilerTasks(NSObject *options, SentryHubInternal *hub)
    NS_SWIFT_NAME(sentry_sdkInitProfilerTasks(_:_:));
FOUNDATION_EXPORT void sentry_test_configureContinuousProfiling(NSObject *options)
    NS_SWIFT_NAME(sentry_configureContinuousProfiling(_:));

NS_ASSUME_NONNULL_END
#endif
