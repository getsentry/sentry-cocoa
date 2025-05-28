#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    if defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)

#        import "SentryDefines.h"

SENTRY_EXTERN unsigned int _gInFlightRootSpans;

#    endif // defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
