#import "SentryTransactionSamplingContext.h"

@implementation SentryTransactionSamplingContext

- (instancetype)initWithTransactionContext:(SentryTransactionContext *)transactionContext
                     customSamplingContext:(NSDictionary<NSString *, id> *)customSamplingContext
{
    if (self = [super init]) {
        _transactionContext = transactionContext;
        _customSamplingContext = customSamplingContext;
    }
    return self;
}

@end
