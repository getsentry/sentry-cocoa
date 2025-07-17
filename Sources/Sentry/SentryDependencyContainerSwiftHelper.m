#import "SentryDependencyContainerSwiftHelper.h"
#import "SentryDependencyContainer.h"
#import "SentrySDK+Private.h"
#import "SentryScope+Private.h"
#import "SentryScope.h"
#import "SentrySwift.h"
#import "SentryUIApplication.h"

@implementation SentryDependencyContainerSwiftHelper

#if SENTRY_HAS_UIKIT

+ (NSArray<UIWindow *> *)windows
{
    return SentryDependencyContainer.sharedInstance.application.windows;
}

#endif // SENTRY_HAS_UIKIT

+ (void)dispatchSyncOnMainQueue:(void (^)(void))block
{
    [SentryDependencyContainer.sharedInstance.dispatchQueueWrapper dispatchSyncOnMainQueue:block];
}

+ (void)applyScopeTo:(SentryEvent *)event
{
    SentryScope *scope = [SentrySDK currentHub].scope;
    SentryOptions *options = SentrySDK.options;
    if (scope != nil && options != nil) {
        [scope applyToEvent:event maxBreadcrumb:options.maxBreadcrumbs];
    }
}

+ (void)captureFatalAppHangEvent:(SentryEvent *)event
{
    [SentrySDK captureFatalAppHangEvent:event];
}

@end
