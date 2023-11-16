#import "SentryAutoSpanStarter.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryDispatchQueueWrapper;

@interface SentryAutoSpanTransactionCarrierStarter : NSObject <SentryAutoSpanStarter>
SENTRY_NO_INIT

- (instancetype)initWithDispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
                                 idleTimeout:(NSTimeInterval)idleTimeout;

+ (BOOL)isCarrierTransaction:(NSString *)operation;

@end

NS_ASSUME_NONNULL_END
