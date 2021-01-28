#import <Sentry/Sentry.h>

NS_ASSUME_NONNULL_BEGIN

@class SentrySpanContext, SentryTransactionContext, SentryHub;

NS_SWIFT_NAME(SentryTransaction)
@interface SentryTransaction : SentryEvent <SentrySerializable>
SENTRY_NO_INIT

- (instancetype)initWithName:(NSString *)name;

- (instancetype)initWithTransactionContext:(SentryTransactionContext *)transactionContext
                                    andHub:(SentryHub *_Nullable)hub;

- (instancetype)initWithName:(NSString *)name
                 spanContext:(SentrySpanContext *)spanContext
                      andHub:(SentryHub *_Nullable)hub;

- (void)finish;

@end

NS_ASSUME_NONNULL_END
