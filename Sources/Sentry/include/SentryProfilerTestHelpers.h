#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryDefines.h"
#    import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Disable profiling when running with TSAN because it produces a TSAN false positive, similar to
 * the situation described here: https://github.com/envoyproxy/envoy/issues/2561
 */
SENTRY_EXTERN BOOL threadSanitizerIsPresent(void);

#    if defined(TEST) || defined(TESTCI) || defined(DEBUG)

SENTRY_EXTERN void writeProfileFile(NSDictionary<NSString *, id> *payload);

#    endif // defined(TEST) || defined(TESTCI) || defined(DEBUG)

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
