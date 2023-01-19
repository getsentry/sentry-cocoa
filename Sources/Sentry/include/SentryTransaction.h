#import "SentryEvent.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryTracer, SentryTransactionContext, SentrySpan;

NS_SWIFT_NAME(Transaction)
@interface SentryTransaction : SentryEvent
SENTRY_NO_INIT

@property (nonatomic, strong) SentryTracer *trace;

- (instancetype)initWithTrace:(SentryTracer *)trace children:(NSArray<SentrySpan *> *)children;

@end

NS_ASSUME_NONNULL_END
