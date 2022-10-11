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

+ (SentryUnitDuration *)nanosecond
{
    return [[SentryUnitDuration alloc] initWithUnit:@"nanoseconds"];
}

+ (SentryUnitDuration *)microsecond
{
    return [[SentryUnitDuration alloc] initWithUnit:@"microsecond"];
}

+ (SentryUnitDuration *)millisecond
{
    return [[SentryUnitDuration alloc] initWithUnit:@"millisecond"];
}

+ (SentryUnitDuration *)second
{
    return [[SentryUnitDuration alloc] initWithUnit:@"second"];
}

+ (SentryUnitDuration *)minute
{
    return [[SentryUnitDuration alloc] initWithUnit:@"minute"];
}

+ (SentryUnitDuration *)hour
{
    return [[SentryUnitDuration alloc] initWithUnit:@"hour"];
}

+ (SentryUnitDuration *)day
{
    return [[SentryUnitDuration alloc] initWithUnit:@"day"];
}

+ (SentryUnitDuration *)week
{
    return [[SentryUnitDuration alloc] initWithUnit:@"week"];
}

@end

@implementation SentryUnitInformation

+ (SentryUnitInformation *)bit
{
    return [[SentryUnitInformation alloc] initWithUnit:@"bit"];
}

+ (SentryUnitInformation *)byte
{
    return [[SentryUnitInformation alloc] initWithUnit:@"byte"];
}

+ (SentryUnitInformation *)kilobyte
{
    return [[SentryUnitInformation alloc] initWithUnit:@"kilobyte"];
}

+ (SentryUnitInformation *)kibibyte
{
    return [[SentryUnitInformation alloc] initWithUnit:@"kibibyte"];
}

+ (SentryUnitInformation *)megabyte
{
    return [[SentryUnitInformation alloc] initWithUnit:@"megabyte"];
}

+ (SentryUnitInformation *)mebibyte
{
    return [[SentryUnitInformation alloc] initWithUnit:@"mebibyte"];
}

+ (SentryUnitInformation *)gigabyte
{
    return [[SentryUnitInformation alloc] initWithUnit:@"gigabyte"];
}

+ (SentryUnitInformation *)gibibyte
{
    return [[SentryUnitInformation alloc] initWithUnit:@"gibibyte"];
}

+ (SentryUnitInformation *)terabyte
{
    return [[SentryUnitInformation alloc] initWithUnit:@"terabyte"];
}

+ (SentryUnitInformation *)tebibyte
{
    return [[SentryUnitInformation alloc] initWithUnit:@"tebibyte"];
}

+ (SentryUnitInformation *)petabyte
{
    return [[SentryUnitInformation alloc] initWithUnit:@"petabyte"];
}

+ (SentryUnitInformation *)pebibyte
{
    return [[SentryUnitInformation alloc] initWithUnit:@"pebibyte"];
}

+ (SentryUnitInformation *)exabyte
{
    return [[SentryUnitInformation alloc] initWithUnit:@"exabyte"];
}

+ (SentryUnitInformation *)exbibyte
{
    return [[SentryUnitInformation alloc] initWithUnit:@"exbibyte"];
}

@end
;

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
