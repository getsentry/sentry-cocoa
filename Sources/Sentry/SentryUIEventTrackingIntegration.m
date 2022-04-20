#import "SentryUIEventTrackingIntegration.h"
#import <Foundation/Foundation.h>
#import <SentryDependencyContainer.h>
#import <SentryUIEventTracker.h>

@interface
SentryUIEventTrackingIntegration ()

@property (nonatomic, strong) SentryUIEventTracker *uiEventTracker;

@end

@implementation SentryUIEventTrackingIntegration

- (void)installWithOptions:(SentryOptions *)options
{
    if (options.enableSwizzling) {
        SentryDependencyContainer *dependencies = [SentryDependencyContainer sharedInstance];
        self.uiEventTracker = [[SentryUIEventTracker alloc]
            initWithSwizzleWrapper:[SentryDependencyContainer sharedInstance].swizzleWrapper
              dispatchQueueWrapper:dependencies.dispatchQueueWrapper];

        [self.uiEventTracker start];
    }
}

- (void)uninstall
{
    if (self.uiEventTracker) {
        [self.uiEventTracker stop];
    }
}

@end
