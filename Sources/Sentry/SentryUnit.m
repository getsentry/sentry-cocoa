#import "SentryUnit.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryUnit

- (instancetype)initWithSymbol:(NSString *)symbol
{
    if (self = [super init]) {
        _symbol = symbol;
    }
    return self;
}

- (id)copyWithZone:(nullable NSZone *)zone
{
    return [[[self class] allocWithZone:zone] initWithSymbol:self.symbol];
}

@end

@implementation SentryUnitDuration

+ (SentryUnitDuration *)nanoseconds
{
    return [[SentryUnitDuration alloc] initWithSymbol:@"nanoseconds"];
}

@end

@implementation SentryUnitInformation

+ (SentryUnitDuration *)bit
{
    return [[SentryUnitDuration alloc] initWithSymbol:@"bit"];
}

@end

@implementation SentryUnitFraction

+ (SentryUnitFraction *)ratio
{
    return [[SentryUnitFraction alloc] initWithSymbol:@"ratio"];
}

+ (SentryUnitFraction *)percent
{
    return [[SentryUnitFraction alloc] initWithSymbol:@"percent"];
}

@end

NS_ASSUME_NONNULL_END
