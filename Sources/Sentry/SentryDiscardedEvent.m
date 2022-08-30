#import "SentryDiscardedEvent.h"
#import "SentryDiscardReasonMapper.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryDiscardedEvent

- (instancetype)initWithReason:(SentryDiscardReason)reason
                      category:(SentryDataCategory)category
                      quantity:(NSUInteger)quantity
{
    if (self = [super init]) {
        _reason = reason;
        _category = category;
        _quantity = quantity;
    }
    return self;
}

- (NSDictionary<NSString *, id> *)serialize
{
    return @{
        @"reason" : discardReasonName(self.reason),
        @"category" : SentryDataCategoryNames[self.category],
        @"quantity" : @(self.quantity)
    };
}

@end

NS_ASSUME_NONNULL_END
