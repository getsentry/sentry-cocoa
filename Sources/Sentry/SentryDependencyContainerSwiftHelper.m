#import "SentryDependencyContainerSwiftHelper.h"
#import "SentryClient+Private.h"
#import "SentryDependencyContainer.h"
#import "SentryHub+Private.h"
#import "SentryOptions+Private.h"
#import "SentrySDK+Private.h"
#import "SentrySwift.h"

@implementation SentryDependencyContainerSwiftHelper

#if SENTRY_HAS_UIKIT

+ (NSArray<UIWindow *> *)windows
{
    return [SentryDependencyContainer.sharedInstance.application getWindows];
}

#endif // SENTRY_HAS_UIKIT

+ (void)dispatchSyncOnMainQueue:(void (^)(void))block
{
    [SentryDependencyContainer.sharedInstance.dispatchQueueWrapper dispatchSyncOnMainQueue:block];
}

+ (id<SentryObjCRuntimeWrapper>)objcRuntimeWrapper
{
    return SentryDependencyContainer.sharedInstance.objcRuntimeWrapper;
}

+ (SentryHub *)currentHub
{
    return SentrySDKInternal.currentHub;
}

+ (nullable NSDictionary *)systemInfo
{
    return SentryDependencyContainer.sharedInstance.crashReporter.systemInfo;
}

+ (BOOL)crashedLastLaunch
{
    return SentryDependencyContainer.sharedInstance.crashReporter.crashedLastLaunch;
}

+ (NSTimeInterval)activeDurationSinceLastCrash
{
    return SentryDependencyContainer.sharedInstance.crashReporter.activeDurationSinceLastCrash;
}

+ (nullable NSDate *)readTimestampLastInForeground
{
    SentryHub *hub = [SentrySDKInternal currentHub];
    return [[[hub getClient] fileManager] readTimestampLastInForeground];
}

+ (void)deleteTimestampLastInForeground
{
    SentryHub *hub = [SentrySDKInternal currentHub];
    [[[hub getClient] fileManager] deleteTimestampLastInForeground];
}

+ (void)storeTimestampLastInForeground:(NSDate *)timestamp
{
    SentryHub *hub = [SentrySDKInternal currentHub];
    [[[hub getClient] fileManager] storeTimestampLastInForeground:timestamp];
}

#if SENTRY_TARGET_PROFILING_SUPPORTED
+ (BOOL)hasProfilingOptions
{
    return SentrySDKInternal.currentHub.client.options.profiling != nil;
}
#endif

@end
