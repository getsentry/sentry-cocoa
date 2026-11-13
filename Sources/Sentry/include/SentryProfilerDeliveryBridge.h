#import "SentryCompiler.h"
#import "SentryDefines.h"
#import "SentryProfilingConditionals.h"
#import "SentryProfilingDispatch.h"
#import <Foundation/Foundation.h>

#if SENTRY_TARGET_PROFILING_SUPPORTED

@class SentryHubInternal;
@class SentryTransaction;
#    if SENTRY_HAS_UIKIT
@class SentryAppStartMeasurement;
#    endif

NS_ASSUME_NONNULL_BEGIN

SENTRY_EXTERN_C_BEGIN

SENTRY_EXTERN void sentry_finishProfiledTransaction(
    SentryHubInternal *hub, SentryProfilingDispatch dispatchAsync, SentryTransaction *transaction,
    BOOL isProfiling, BOOL isLaunchTrace, BOOL continuousTraceProfiling,
    NSDate *_Nullable traceStartTimestamp, uint64_t startSystemTime
#    if SENTRY_HAS_UIKIT
    ,
    SentryAppStartMeasurement *_Nullable appStartMeasurement
#    endif
);

SENTRY_EXTERN_C_END

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
