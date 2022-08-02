#import "SentryUIEventTrackingIntegration.h"
#import <Foundation/Foundation.h>
#import <SentryDependencyContainer.h>
#import <SentryLog.h>
#import <SentryNSDataSwizzling.h>
#import <SentryOptions+Private.h>
#import <SentryOptions.h>
#import <SentryUIEventTracker.h>

#if SENTRY_HAS_UIKIT
@interface
SentryUIEventTrackingIntegration ()

@property (nonatomic, strong) SentryUIEventTracker *uiEventTracker;

@end

@implementation SentryUIEventTrackingIntegration

- (void)installWithOptions:(SentryOptions *)options
{
    if (![self shouldBeEnabled:@[
            [[SentryOptionWithDescription alloc]
                initWithOption:options.enableAutoPerformanceTracking
                    optionName:@"enableAutoPerformanceTracking"],
            [[SentryOptionWithDescription alloc] initWithOption:options.enableSwizzling
                                                     optionName:@"enableSwizzling"],
            [[SentryOptionWithDescription alloc] initWithOption:options.isTracingEnabled
                                                     optionName:@"isTracingEnabled"],
            [[SentryOptionWithDescription alloc] initWithOption:options.enableUserInteractionTracing
                                                     optionName:@"enableUserInteractionTracing"],
        ]]) {
        [options removeEnabledIntegration:NSStringFromClass([self class])];
        return;
    }

    SentryDependencyContainer *dependencies = [SentryDependencyContainer sharedInstance];
    self.uiEventTracker = [[SentryUIEventTracker alloc]
        initWithSwizzleWrapper:[SentryDependencyContainer sharedInstance].swizzleWrapper
          dispatchQueueWrapper:dependencies.dispatchQueueWrapper
                   idleTimeout:options.idleTimeout];

    [self.uiEventTracker start];
}

- (void)uninstall
{
    if (self.uiEventTracker) {
        [self.uiEventTracker stop];
    }
}

@end
#endif
