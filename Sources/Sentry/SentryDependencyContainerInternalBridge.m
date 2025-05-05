#import "SentryDependencyContainerInternalBridge.h"

#import "SentryDependencyContainer.h"

@implementation SentryDependencyContainerInternalBridge

+ (SentryPerformanceTracker *)getPerformanceTracker
{
    return [[SentryDependencyContainer sharedInstance] performanceTracker];
}

@end
