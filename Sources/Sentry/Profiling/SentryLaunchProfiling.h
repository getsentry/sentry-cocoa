#import "SentryDefines.h"
#import "SentryProfilingConditionals.h"
#import <Foundation/Foundation.h>

#if SENTRY_TARGET_PROFILING_SUPPORTED

@class SentryId;
@class SentryOptions;
@class SentryTracerConfiguration;
@class SentryTransactionContext;

NS_ASSUME_NONNULL_BEGIN

SENTRY_EXTERN BOOL isTracingAppLaunch;
SENTRY_EXTERN SentryId *_Nullable appLaunchTraceId;
SENTRY_EXTERN uint64_t appLaunchSystemTime;
SENTRY_EXTERN NSObject *appLaunchTraceLock;

SENTRY_EXTERN NSString *const kSentryLaunchProfileConfigKeyTracesSampleRate;
SENTRY_EXTERN NSString *const kSentryLaunchProfileConfigKeyProfilesSampleRate;
SENTRY_EXTERN NSDictionary<NSString *, NSNumber *> *lastLaunchSampleRates(void);

void startLaunchProfile(void);

void configureLaunchProfiling(SentryOptions *options);

/**
 * If there were previously persisted sampling rates sed when decidign the launch profile/trace,
 * inject them into the context and configuration.
 * @return @c YES if persisted rates were found and injected, @c NO otherwise.
 */
BOOL injectLaunchSamplerDecisions(
    SentryTransactionContext *transactionContext, SentryTracerConfiguration *configuration);

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
