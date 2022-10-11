#import "SentryMeasurement.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryMeasurement

- (instancetype)initWithName:(NSString *)name
                       value:(NSNumber *)value
                        unit:(SentryMeasurementUnit *)unit
{
    if (self = [super init]) {
        _name = name;
        _value = value;
        _unit = unit;
    }
    return self;
}

- (NSDictionary<NSString *, id> *)serialize
{
    return @{ @"name" : self.name, @"value" : self.value, @"unit" : self.unit.unit };
}

@end

NS_ASSUME_NONNULL_END
