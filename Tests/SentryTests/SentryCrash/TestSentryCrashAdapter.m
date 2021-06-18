#import "TestSentryCrashAdapter.h"
#import <Foundation/Foundation.h>

@implementation TestSentryCrashAdapter

+ (instancetype)sharedInstance
{
    TestSentryCrashAdapter *instance = [[self alloc] init];
    instance.internalActiveDurationSinceLastCrash = NO;
    instance.internalActiveDurationSinceLastCrash = 0;
    instance.internalIsBeingTraced = NO;
    instance.installAsyncHooksCalled = NO;
    instance.deactivateAsyncHooksCalled = NO;
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

- (void)installAsyncHooks
{
    self.installAsyncHooksCalled = YES;
}

- (void)deactivateAsyncHooks
{
    self.deactivateAsyncHooksCalled = YES;
}

@end
