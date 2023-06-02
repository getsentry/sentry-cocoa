#import "TestSentryCrashWrapper.h"
#import "SentryCrash.h"
#import <Foundation/Foundation.h>

@implementation TestSentryCrashWrapper

+ (instancetype)sharedInstance
{
    TestSentryCrashWrapper *instance = [[self alloc] init];
    instance.internalActiveDurationSinceLastCrash = NO;
    instance.internalDurationFromCrashStateInitToLastCrash = 0;
    instance.internalActiveDurationSinceLastCrash = 0;
    instance.internalIsBeingTraced = NO;
    instance.internalIsSimulatorBuild = NO;
    instance.internalIsApplicationInForeground = YES;
    instance.installAsyncHooksCalled = NO;
    instance.uninstallAsyncHooksCalled = NO;
    instance.internalFreeMemorySize = 0;
    instance.internalAppMemorySize = 0;
    instance.internalFreeStorageSize = 0;
    return instance;
}

- (void)startBinaryImageCache
{
    _binaryCacheStarted = YES;
    [super startBinaryImageCache];
}

- (void)stopBinaryImageCache
{
    [super stopBinaryImageCache];
    _binaryCacheStopped = YES;
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
