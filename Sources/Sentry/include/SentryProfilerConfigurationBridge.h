#import "SentryCompiler.h"
#import "SentryDefines.h"
#import "SentryProfilingConfiguration.h"
#import "SentryProfilingTraceDecision.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

@class SentryClientInternal;
@class SentryHubInternal;
@class SentryOptions;
@class SentryTracerConfiguration;
@class SentryTransactionContext;

NS_ASSUME_NONNULL_BEGIN

SENTRY_EXTERN_C_BEGIN

/**
 * Perform necessary profiler tasks that should take place when the SDK starts: configure the next
 * launch's profiling, stop tracer profiling if no automatic performance transaction is running,
 * start the continuous profiler if enabled and not profiling from launch.
 */
SENTRY_EXTERN void sentry_sdkInitProfilerTasks(SentryOptions *options, SentryHubInternal *hub);
SENTRY_EXTERN void sentry_configureContinuousProfiling(SentryOptions *options);

SENTRY_EXTERN SentryProfilingConfiguration sentry_profilerConfigurationSnapshot(void);
SENTRY_EXTERN SentryProfilingTraceDecision sentry_profilerTraceDecision(
    SENTRY_SWIFT_MIGRATION_ID(SentryTracerConfiguration) configuration,
    SentryHubInternal *_Nullable hub, SentryTransactionContext *transactionContext);
SENTRY_EXTERN BOOL sentry_profilerUsesTraceLifecycle(SentryClientInternal *_Nullable client);

SENTRY_EXTERN_C_END

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
