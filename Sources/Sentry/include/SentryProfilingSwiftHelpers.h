#import "SentryProfilingConditionals.h"
#import <Foundation/Foundation.h>

@class SentryId;
@class SentryProfileOptions;
@class SentrySpanId;
@class SentryClientInternal;
@class SentryDispatchQueueWrapper;
@class SentryScreenFrames;
@class SentryTracer;
@class SentryTransactionContext;

NS_ASSUME_NONNULL_BEGIN

// The functions in this file exist to bridge ObjectiveC++ to Swift. When building with Swift
// Package Manager you can’t import Swift into ObjectiveC++ so instead that code calls plain C
// functions in this file which then uses Swift in their implementation.

#ifdef __cplusplus
extern "C" {
#endif

BOOL sentry_isContinuousProfilingEnabled(SentryClientInternal *client);
BOOL sentry_isProfilingCorrelatedToTraces(SentryClientInternal *client);
SentryProfileOptions *_Nullable sentry_getProfiling(SentryClientInternal *client);
NSString *sentry_stringFromSentryID(SentryId *sentryID);

SentryId *sentry_getSentryId(void);
SentryProfileOptions *sentry_getSentryProfileOptions(void);
BOOL sentry_isTraceLifecycle(SentryProfileOptions *options);
float sentry_sessionSampleRate(SentryProfileOptions *options);
BOOL sentry_profileAppStarts(SentryProfileOptions *options);
SentrySpanId *_Nullable sentry_getParentSpanID(SentryTransactionContext *context);
SentryId *sentry_getTraceID(SentryTransactionContext *context);
BOOL sentry_isNotSampled(SentryTransactionContext *context);

#if SENTRY_HAS_UIKIT
#    if !SDK_V10
BOOL sentry_appHangsDisabled(void);
#    endif // !SDK_V10
BOOL sentry_autoPerformanceTracingDisabled(void);

#endif // SENTRY_HAS_UIKIT

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
