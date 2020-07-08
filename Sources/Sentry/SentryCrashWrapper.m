#import "SentryCrashWrapper.h"
#import "SentryCrash.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@implementation SentryCrashWrapper

- (BOOL)crashedLastLaunch
{
    return SentryCrash.sharedInstance.crashedLastLaunch;
}

- (NSTimeInterval)activeDurationSinceLastCrash
{
    return SentryCrash.sharedInstance.activeDurationSinceLastCrash;
}

@end

NS_ASSUME_NONNULL_END
