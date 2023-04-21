#import "TestSentryCrashWrapper.h"
#import "SentryCrash.h"
#import <Foundation/Foundation.h>

@implementation TestSentryCrashWrapper

- (instancetype)init
{
    if (!(self = [super init])) {
        return nil;
    }

    _internalActiveDurationSinceLastCrash = NO;
    _internalDurationFromCrashStateInitToLastCrash = 0;
    _internalActiveDurationSinceLastCrash = 0;
    _internalIsBeingTraced = NO;
    _internalIsSimulatorBuild = NO;
    _internalIsApplicationInForeground = YES;
    _installAsyncHooksCalled = NO;
    _uninstallAsyncHooksCalled = NO;
    _internalFreeMemorySize = 0;
    _internalAppMemorySize = 0;
    _internalFreeStorageSize = 0;

    return self;
}

- (BOOL)crashedLastLaunch
{
    return self.internalCrashedLastLaunch;
}

- (NSTimeInterval)durationFromCrashStateInitToLastCrash
{
    return self.internalDurationFromCrashStateInitToLastCrash;
}

- (NSTimeInterval)activeDurationSinceLastCrash
{
    return self.internalActiveDurationSinceLastCrash;
}

- (BOOL)isBeingTraced
{
    return self.internalIsBeingTraced;
}

- (BOOL)isSimulatorBuild
{
    return self.internalIsSimulatorBuild;
}

- (BOOL)isApplicationInForeground
{
    return self.internalIsApplicationInForeground;
}

- (void)installAsyncHooks
{
    self.installAsyncHooksCalled = YES;
}

- (void)uninstallAsyncHooks
{
    self.uninstallAsyncHooksCalled = YES;
}

- (NSDictionary *)systemInfo
{
    return @{};
}

- (bytes)freeMemorySize
{
    return self.internalFreeMemorySize;
}

- (bytes)appMemorySize
{
    return self.internalAppMemorySize;
}

- (bytes)freeStorageSize
{
    return self.internalFreeStorageSize;
}

@end
