#import "SentryLaunchProfiling.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryDefines.h"
#    import "SentryProfiler+Private.h"

@class SentryOptions;
@class SentrySamplerDecision;

NS_ASSUME_NONNULL_BEGIN

/**
 * `sentry_shouldProfileNextLaunch` cannot be exposed to Swift tests because its return type is not
 * expressible in Swift. This wraps it and only returns the `BOOL shouldProfile` value in the
 * struct.
 */
BOOL sentry_willProfileNextLaunch(SentryOptions *options);

/**
 * Contains the logic to start a launch profile. Exposed separately from @c
 * sentry_startLaunchProfile, because that function wraps everything in a @c dispatch_once , and
 * that path is taken once when @c SenryProfiler.load is called at the start of the test suite, and
 * can't be executed again by calling that function.
 */
void _sentry_nondeduplicated_startLaunchProfile(void);

SentryTransactionContext *sentry_contextForLaunchProfilerForTrace(
    NSNumber *tracesRate, NSNumber *tracesRand);

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
