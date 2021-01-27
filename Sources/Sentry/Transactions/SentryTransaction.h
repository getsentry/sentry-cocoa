#import <Sentry/Sentry.h>

NS_ASSUME_NONNULL_BEGIN

@class SentrySpanContext, SentryTransactionContext, SentryHub;

NS_SWIFT_NAME(Transaction)
@interface SentryTransaction : SentryEvent <SentrySerializable>
SENTRY_NO_INIT

- (instancetype)initWithName:(NSString *)name;

- (instancetype)initWithTransactionContext:(SentryTransactionContext *)context
                                    andHub:(SentryHub *_Nullable)hub;

- (instancetype)initWithName:(NSString *)name
                     context:(SentrySpanContext *)context
                      andHub:(SentryHub *_Nullable)hub;

- (void)finish;

@end

NS_ASSUME_NONNULL_END
