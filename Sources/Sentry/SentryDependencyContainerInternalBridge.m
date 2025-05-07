#import "SentryDependencyContainerInternalBridge.h"

#import "SentryDependencyContainer.h"

@implementation SentryDependencyContainerInternalBridge

+ (SentryPerformanceTracker *)getPerformanceTracker
{
    return [[SentryDependencyContainer sharedInstance] performanceTracker];
}

#if SENTRY_HAS_UIKIT
+ (SentryUIViewControllerPerformanceTracker *)getUiViewControllerPerformanceTracker
{
    return [[SentryDependencyContainer sharedInstance] uiViewControllerPerformanceTracker];
}
#endif

@end
