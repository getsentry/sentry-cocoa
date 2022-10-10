#import "SentryUnit.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryUnit

- (instancetype)initWithUnit:(NSString *)unit
{
    if (self = [super init]) {
        _unit = unit;
    }
    return self;
}

- (id)copyWithZone:(nullable NSZone *)zone
{
    return [[[self class] allocWithZone:zone] initWithSymbol:self.unit];
}

@end

@implementation SentryUnitDuration

+ (SentryUnitDuration *)nanoseconds
{
    return [[SentryUnitDuration alloc] initWithUnit:@"nanoseconds"];
}

@end

@implementation SentryUnitInformation

+ (SentryUnitDuration *)bit
{
    return [[SentryUnitDuration alloc] initWithUnit:@"bit"];
}

@end

@implementation SentryUnitFraction

+ (SentryUnitFraction *)ratio
{
    return [[SentryUnitFraction alloc] initWithUnit:@"ratio"];
}

+ (SentryUnitFraction *)percent
{
    return [[SentryUnitFraction alloc] initWithUnit:@"percent"];
}

@end

NS_ASSUME_NONNULL_END
