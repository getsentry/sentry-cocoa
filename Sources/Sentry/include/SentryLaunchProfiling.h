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

void startLaunchProfile(void);

/**
 * Write a file to disk containing sample rates for profiles and traces. The presence of this file
 * will let the profiler know to start on the app launch, and the sample rates contained will help
 * thread sampling decisions through to SentryHub later when it needs to start a transaction for the
 * profile to be attached to.
 */
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
