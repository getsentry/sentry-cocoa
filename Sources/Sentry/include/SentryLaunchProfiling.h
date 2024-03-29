#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryDefines.h"
#    import <Foundation/Foundation.h>

@class SentryHub;
@class SentryId;
@class SentryOptions;

#    if SENTRY_PROFILING_MODE_LEGACY

@class SentryTracerConfiguration;
@class SentryTransactionContext;

SENTRY_EXTERN BOOL isTracingAppLaunch;

#    endif // SENTRY_PROFILING_MODE_LEGACY

NS_ASSUME_NONNULL_BEGIN

/** Try to start a profiled trace for this app launch, if the configuration allows. */
SENTRY_EXTERN void startLaunchProfile(void);

#    if SENTRY_PROFILING_MODE_LEGACY

/**
 * Stop any profiled trace that may be in flight from the start of the app launch, and transmit the
 * dedicated transaction with the profiling data attached.
 */
void stopAndTransmitLaunchProfile(SentryHub *hub);

/**
 * Stop the tracer that started the launch profiler. Use when the profiler will be attached to an
 * app start transaction and doesn't need to be attached to a dedicated tracer. The tracer managing
 * the profiler will be discarded in this case.
 */
void stopAndDiscardLaunchProfileTracer(void);

#    endif // SENTRY_PROFILING_MODE_LEGACY

/**
 * Write a file to disk containing sample rates for profiles and traces. The presence of this file
 * will let the profiler know to start on the app launch, and the sample rates contained will help
 * thread sampling decisions through to SentryHub later when it needs to start a transaction for the
 * profile to be attached to.
 */
void configureLaunchProfiling(SentryOptions *options);

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
