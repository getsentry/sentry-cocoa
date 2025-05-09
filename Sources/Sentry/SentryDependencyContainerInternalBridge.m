#import "SentryDependencyContainerInternalBridge.h"

#import "SentryDependencyContainer.h"

@implementation SentryDependencyContainerInternalBridge

+ (SentryPerformanceTracker *)getPerformanceTracker
{
    return [[SentryDependencyContainer sharedInstance] performanceTracker];
}

+ (SentryUIViewControllerPerformanceTracker *)getUiViewControllerPerformanceTracker
{
    return [[SentryDependencyContainer sharedInstance] uiViewControllerPerformanceTracker];
}

@end
