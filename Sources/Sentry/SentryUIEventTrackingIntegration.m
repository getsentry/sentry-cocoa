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
    if ([self shouldBeDisabled:options]) {
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

- (BOOL)shouldBeDisabled:(SentryOptions *)options
{
    if (!options.enableAutoPerformanceTracking) {
        [SentryLog logWithMessage:@"Not going to enable User Interaction tracking because "
                                  @"enableAutoPerformanceTracking is disabled."
                         andLevel:kSentryLevelDebug];
        return YES;
    }

    if (!options.enableSwizzling) {
        [SentryLog logWithMessage:@"Not going to enable User Interaction tracking because "
                                  @"enableSwizzling is disabled."
                         andLevel:kSentryLevelDebug];
        return YES;
    }

    if (!options.isTracingEnabled) {
        [SentryLog logWithMessage:
                       @"Not going to enable User Interaction tracking because tracing is disabled."
                         andLevel:kSentryLevelDebug];
        return YES;
    }

    if (!options.enableUserInteractionTracing) {
        [SentryLog logWithMessage:@"Not going to enable User Interaction tracking because "
                                  @"enableUserInteractionTracing is disabled."
                         andLevel:kSentryLevelDebug];
        return YES;
    }

    return NO;
}

- (void)uninstall
{
    if (self.uiEventTracker) {
        [self.uiEventTracker stop];
    }
}

@end
#endif
