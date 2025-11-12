#import "SentryDependencyContainerSwiftHelper.h"
#import "SentryClient+Private.h"
#import "SentryHub+Private.h"
#import "SentrySDK+Private.h"
#import "SentrySwift.h"

@implementation SentryDependencyContainerSwiftHelper

#if SENTRY_HAS_UIKIT

+ (NSArray<UIWindow *> *)windows
{
    return [SentryDependencyContainer.sharedInstance.application getWindows];
}

#endif // SENTRY_HAS_UIKIT

+ (NSString *)release:(SentryOptions *)options
{
    return options.releaseName;
}

+ (SentryLog *)beforeSendLog:(SentryLog *)log options:(SentryOptions *)options
{
    if (options.beforeSendLog) {
        return options.beforeSendLog(log);
    }
    return log;
}

+ (NSString *)environment:(SentryOptions *)options
{
    return options.environment;
}

+ (BOOL)enableLogs:(SentryOptions *)options
{
    return options.enableLogs;
}

+ (NSArray<NSString *> *)enabledFeatures:(SentryOptions *)options
{
    return [SentryEnabledFeaturesBuilder getEnabledFeaturesWithOptions:options];
}

+ (BOOL)sendDefaultPii:(SentryOptions *)options
{
    return options.sendDefaultPii;
}

+ (SentryDispatchQueueWrapper *)dispatchQueueWrapper
{
    return SentryDependencyContainer.sharedInstance.dispatchQueueWrapper;
}

+ (void)dispatchSyncOnMainQueue:(void (^)(void))block
{
    [SentryDependencyContainer.sharedInstance.dispatchQueueWrapper dispatchSyncOnMainQueue:block];
}

+ (nullable NSDate *)readTimestampLastInForeground
{
    SentryHubInternal *hub = [SentrySDKInternal currentHub];
    return [[[hub getClient] fileManager] readTimestampLastInForeground];
}

+ (void)deleteTimestampLastInForeground
{
    SentryHubInternal *hub = [SentrySDKInternal currentHub];
    [[[hub getClient] fileManager] deleteTimestampLastInForeground];
}

+ (void)storeTimestampLastInForeground:(NSDate *)timestamp
{
    SentryHubInternal *hub = [SentrySDKInternal currentHub];
    [[[hub getClient] fileManager] storeTimestampLastInForeground:timestamp];
}

#if SENTRY_TARGET_PROFILING_SUPPORTED
+ (BOOL)hasProfilingOptions
{
    return SentrySDKInternal.currentHub.client.options.profiling != nil;
}
#endif

@end
