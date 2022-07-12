#import "SentryAppStartMeasurement.h"
#import "NSDate+SentryExtras.h"
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
               runtimeInitTimestamp:runtimeInitTimestamp
                      mainTimestamp:[NSDate dateWithTimeIntervalSince1970:0]
        didFinishLaunchingTimestamp:didFinishLaunchingTimestamp];
}

- (instancetype)initWithType:(SentryAppStartType)type
              appStartTimestamp:(NSDate *)appStartTimestamp
                       duration:(NSTimeInterval)duration
           runtimeInitTimestamp:(NSDate *)runtimeInitTimestamp
                  mainTimestamp:(NSDate *)mainTimestamp
    didFinishLaunchingTimestamp:(NSDate *)didFinishLaunchingTimestamp
{
    if (self = [super init]) {
        _type = type;
        _appStartTimestamp = appStartTimestamp;
        _duration = duration;
        _runtimeInitTimestamp = runtimeInitTimestamp;
        _mainTimestamp = mainTimestamp;
        _didFinishLaunchingTimestamp = didFinishLaunchingTimestamp;
    }

    return self;
}

@end
