#import "SentryCrashAdapter.h"
#import "SentryCrash.h"
#import <Foundation/Foundation.h>
#import <SentryCrashDebug.h>

NS_ASSUME_NONNULL_BEGIN

@implementation SentryCrashAdapter

+ (instancetype)sharedInstance
{
    static SentryCrashAdapter *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (BOOL)crashedLastLaunch
{
    return SentryCrash.sharedInstance.crashedLastLaunch;
}

- (NSTimeInterval)activeDurationSinceLastCrash
{
    return SentryCrash.sharedInstance.activeDurationSinceLastCrash;
}

- (BOOL)isBeingTraced
{
    return sentrycrashdebug_isBeingTraced();
}

@end

NS_ASSUME_NONNULL_END
