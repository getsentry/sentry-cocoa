#import "SentryDefines.h"
#import "SentryProfilingConditionals.h"
#import <Foundation/Foundation.h>

#if SENTRY_TARGET_PROFILING_SUPPORTED

@class SentryId;
@class SentryOptions;
@class SentryTracesSamplerDecision;

NS_ASSUME_NONNULL_BEGIN

/**
 * This is calculated when @c +[SentryTracer @c load] is called, so we don't run the
 * profiler for a launch and then later have the @c tracesSamplerDecision return @c NO, throwing
 * out the data and effectively having caused unnecessary launch overhead. We expose this here so
 * that in the place where the hub requests a sampling decision on whether to start a trace, if it's
 * for the SDK start trace, this decision is used, so that we don't recompute it and possibly get
 * a disagreement.
 */
SENTRY_EXTERN SentryTracesSamplerDecision *appLaunchTraceSamplerDecision;
SENTRY_EXTERN BOOL isTracingAppLaunch;
SENTRY_EXTERN SentryId *_Nullable appLaunchTraceId;
SENTRY_EXTERN uint64_t appLaunchSystemTime;
SENTRY_EXTERN NSObject *appLaunchTraceLock;

void startLaunchProfile(void);

void configureLaunchProfiling(SentryOptions *options);

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
