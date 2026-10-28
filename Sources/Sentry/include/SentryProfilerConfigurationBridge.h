#import "SentryCompiler.h"
#import "SentryDefines.h"
#import "SentryProfilingConfiguration.h"
#import "SentryProfilingTraceDecision.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

@class SentryClientInternal;
@class SentryHubInternal;
@class SentryTracerConfiguration;
@class SentryTransactionContext;

NS_ASSUME_NONNULL_BEGIN

SENTRY_EXTERN_C_BEGIN

SENTRY_EXTERN SentryProfilingConfiguration sentry_profilerConfigurationSnapshot(void);
SENTRY_EXTERN SentryProfilingTraceDecision sentry_profilerTraceDecision(
    SENTRY_SWIFT_MIGRATION_ID(SentryTracerConfiguration) configuration,
    SentryHubInternal *_Nullable hub, SentryTransactionContext *transactionContext);
SENTRY_EXTERN BOOL sentry_profilerUsesTraceLifecycle(SentryClientInternal *_Nullable client);

SENTRY_EXTERN_C_END

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
