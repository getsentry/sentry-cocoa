#import "SentryLaunchProfiling.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryDefines.h"

@class SentrySamplerDecision;
@class SentryOptions;

NS_ASSUME_NONNULL_BEGIN

typedef struct {
    BOOL shouldProfile;
    SentrySamplerDecision *_Nullable tracesDecision;
    SentrySamplerDecision *_Nullable profilesDecision;
} SentryLaunchProfileConfig;

SENTRY_EXTERN NSString *const kSentryLaunchProfileConfigKeyTracesSampleRate;
SENTRY_EXTERN NSString *const kSentryLaunchProfileConfigKeyProfilesSampleRate;

SentryLaunchProfileConfig sentry_shouldProfileNextLaunch(SentryOptions *options);

/**
 * `sentry_shouldProfileNextLaunch` cannot be exposed to Swift tests because its return type is not
 * expressible in Swift. This wraps it and only returns the `BOOL shouldProfile` value in the
 * struct.
 */
BOOL sentry_willProfileNextLaunch(SentryOptions *options);

SentryTransactionContext *sentry_context(NSNumber *tracesRate);

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
