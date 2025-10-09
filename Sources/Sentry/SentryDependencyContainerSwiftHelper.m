#import "SentryDependencyContainerSwiftHelper.h"
#import "SentryDependencyContainer.h"
#import "SentrySDK+Private.h"
#import "SentrySwift.h"

@implementation SentryDependencyContainerSwiftHelper

#if SENTRY_HAS_UIKIT

+ (NSArray<UIWindow *> *)windows
{
    return [SentryDependencyContainer.sharedInstance.application getWindows];
}

#endif // SENTRY_HAS_UIKIT

+ (SentryFileIOTracker *_Nullable)fileIOTracker
{
    // It is necessary to check if the SDK is enabled because accessing the tracker will otherwise
    // initialize the depency container without any configured SDK options. This is a known issue
    // and needs to be fixed in general.
    if (!SentrySDK.isEnabled) {
        return nil;
    }
    return SentryDependencyContainer.sharedInstance.fileIOTracker;
}

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

+ (SentryCrash *)crashReporter
{
    return SentryDependencyContainer.sharedInstance.crashReporter;
}

@end
