#import "SentryAppStartMeasurement.h"
#import <Foundation/Foundation.h>

@implementation SentryAppStartMeasurement

- (instancetype)initWithType:(SentryAppStartType)type
              appStartTimestamp:(NSDate *)appStartTimestamp
                       duration:(NSTimeInterval)duration
           runtimeInitTimestamp:(NSDate *)runtimeInitTimestamp
    didFinishLaunchingTimestamp:(NSDate *)didFinishLaunchingTimestamp
{
    return [self initWithType:type
                  appStartTimestamp:appStartTimestamp
                           duration:duration
                      mainTimestamp:[NSDate dateWithTimeIntervalSince1970:0]
               runtimeInitTimestamp:runtimeInitTimestamp
        didFinishLaunchingTimestamp:didFinishLaunchingTimestamp];
}

- (instancetype)initWithType:(SentryAppStartType)type
              appStartTimestamp:(NSDate *)appStartTimestamp
                       duration:(NSTimeInterval)duration
                  mainTimestamp:(NSDate *)mainTimestamp
           runtimeInitTimestamp:(NSDate *)runtimeInitTimestamp
    didFinishLaunchingTimestamp:(NSDate *)didFinishLaunchingTimestamp
{
    if (self = [super init]) {
        _type = type;
        _appStartTimestamp = appStartTimestamp;
        _duration = duration;
        _mainTimestamp = mainTimestamp;
        _runtimeInitTimestamp = runtimeInitTimestamp;
        _didFinishLaunchingTimestamp = didFinishLaunchingTimestamp;
    }

    return self;
}

@end
