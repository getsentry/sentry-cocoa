#import "SentryProfilingConditionals.h"
#import <Foundation/Foundation.h>

@class SentryId;
@class SentryTransactionContext;

NS_ASSUME_NONNULL_BEGIN

// The functions in this file exist to bridge ObjectiveC++ to Swift. When building with Swift
// Package Manager you can’t import Swift into ObjectiveC++ so instead that code calls plain C
// functions in this file which then uses Swift in their implementation.

#ifdef __cplusplus
extern "C" {
#endif

NSString *sentry_stringFromSentryID(SentryId *sentryID);
SentryId *sentry_getSentryId(void);
SentryId *sentry_getTraceID(SentryTransactionContext *context);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
