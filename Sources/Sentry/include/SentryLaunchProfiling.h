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

/** Try to start a profiled trace for this app launch, if the configuration allows. */
void startLaunchProfile(void);

/** Stop any profiled trace that may be in flight from the start of the app launch. */
void stopLaunchProfile(void);

/**
 * Write a file to disk containing sample rates for profiles and traces. The presence of this file
 * will let the profiler know to start on the app launch, and the sample rates contained will help
 * thread sampling decisions through to SentryHub later when it needs to start a transaction for the
 * profile to be attached to.
 */
void configureLaunchProfiling(SentryOptions *options);

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
