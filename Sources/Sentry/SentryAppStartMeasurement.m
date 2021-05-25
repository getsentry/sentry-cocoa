#import "SentryAppStartMeasurement.h"
#import <Foundation/Foundation.h>

@implementation SentryAppStartMeasurement

- (instancetype)initWithType:(SentryAppStartType)type duration:(NSTimeInterval)duration
{
    if (self = [super init]) {
        _type = type;
        _duration = duration;
    }

    return self;
}

@end
