#import "SentryUIEventTrackingIntegration.h"

#if UIKIT_LINKED

#    import <SentryDependencyContainer.h>
#    import <SentryLog.h>
#    import <SentryNSDataSwizzling.h>
#    import <SentryOptions+Private.h>
#    import <SentryOptions.h>
#    import <SentryUIEventTracker.h>

@interface
SentryUIEventTrackingIntegration ()

@property (nonatomic, strong) SentryUIEventTracker *uiEventTracker;

@end

@implementation SentryUIEventTrackingIntegration

- (BOOL)installWithOptions:(SentryOptions *)options
{
    if (![super installWithOptions:options]) {
        return NO;
    }

    SentryDependencyContainer *dependencies = [SentryDependencyContainer sharedInstance];
    self.uiEventTracker =
        [[SentryUIEventTracker alloc] initWithDispatchQueueWrapper:dependencies.dispatchQueueWrapper
                                                       idleTimeout:options.idleTimeout];

    [self.uiEventTracker start];

    return YES;
}

- (SentryIntegrationOption)integrationOptions
{
    return kIntegrationOptionEnableAutoPerformanceTracing | kIntegrationOptionEnableSwizzling
        | kIntegrationOptionIsTracingEnabled | kIntegrationOptionEnableUserInteractionTracing;
}

- (void)uninstall
{
    if (self.uiEventTracker) {
        [self.uiEventTracker stop];
    }
}

@end

#endif // UIKIT_LINKED
