#import "TestSentryCrashWrapper.h"
#import "SentryCrash.h"
#import <Foundation/Foundation.h>

@implementation TestSentryCrashWrapper

+ (instancetype)sharedInstance
{
    TestSentryCrashWrapper *instance = [[self alloc] init];
    instance.internalActiveDurationSinceLastCrash = NO;
    instance.internalActiveDurationSinceLastCrash = 0;
    instance.internalIsBeingTraced = NO;
    instance.internalIsApplicationInForeground = YES;
    instance.installAsyncHooksCalled = NO;
    instance.closeCalled = NO;
    return instance;
}

- (BOOL)crashedLastLaunch
{
    return self.internalCrashedLastLaunch;
}

- (NSTimeInterval)activeDurationSinceLastCrash
{
    return self.internalActiveDurationSinceLastCrash;
}

- (BOOL)isBeingTraced
{
    return self.internalIsBeingTraced;
}

- (BOOL)isApplicationInForeground
{
    return self.internalIsApplicationInForeground;
}

- (void)installAsyncHooks
{
    self.installAsyncHooksCalled = YES;
}

- (void)close
{
    self.closeCalled = YES;
}

- (NSDictionary *)systemInfo
{
    return @{};
}

@end
