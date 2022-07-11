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

- (NSDictionary<NSString *, id> *)serialize
{
    NSMutableDictionary *serializedData = [NSMutableDictionary new];

    switch (self.type) {
    case SentryAppStartTypeCold:
        serializedData[@"type"] = @"Cold Start";
        break;
    case SentryAppStartTypeWarm:
        serializedData[@"type"] = @"Warm Start";
        break;
    default:
        serializedData[@"type"] = @"Unknown Start";
    }

    serializedData[@"appStartTimestamp"] = [self.appStartTimestamp sentry_toIso8601String];
    serializedData[@"duration"] = @(self.duration);
    serializedData[@"mainTimestamp"] = [self.mainTimestamp sentry_toIso8601String];
    serializedData[@"runtimeInitTimestamp"] = [self.runtimeInitTimestamp sentry_toIso8601String];
    serializedData[@"didFinishLaunchingTimestamp"] =
        [self.didFinishLaunchingTimestamp sentry_toIso8601String];

    return serializedData;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p, %@>", [self class], self, [self serialize]];
}

@end
