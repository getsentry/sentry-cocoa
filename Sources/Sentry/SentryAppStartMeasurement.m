#import "SentryAppStartMeasurement.h"
#import <Foundation/Foundation.h>

@implementation SentryAppStartMeasurement

- (instancetype)initWithType:(SentryAppStartType)type
                   appStartDate:(NSDate *)appStartTimestamp
                       duration:(NSTimeInterval)duration
                    runtimeInit:(NSDate *)runtimeInit
    didFinishLaunchingTimestamp:(NSDate *)didFinishLaunchingTimestamp
{
    if (self = [super init]) {
        _type = type;
        _appStartTimestamp = appStartTimestamp;
        _duration = duration;
        _runtimeInit = runtimeInit;
        _didFinishLaunchingTimestamp = didFinishLaunchingTimestamp;
    }

    return self;
}

@end
