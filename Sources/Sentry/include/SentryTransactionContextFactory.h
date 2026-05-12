#import "SentryDefines.h"
#import "SentryTransactionContext.h"

@class SentryId;

NS_ASSUME_NONNULL_BEGIN

SENTRY_EXTERN SentryTransactionContext *SentryTransactionContextCreate(
    NSString *name, NSInteger nameSource, NSString *operation, NSString *origin);

SENTRY_EXTERN SentryTransactionContext *SentryTransactionContextCreateWithTraceId(
    SentryId *traceId, NSString *name, NSInteger nameSource, NSString *operation, NSString *origin);

NS_ASSUME_NONNULL_END
