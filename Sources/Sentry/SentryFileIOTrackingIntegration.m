#import "SentryFileIOTrackingIntegration.h"
#import "SentrySwift.h"

@interface SentryFileIOTrackingIntegration ()

@property (nonatomic, strong) SentryFileIOTracker *tracker;

@end

@implementation SentryFileIOTrackingIntegration

- (BOOL)installWithOptions:(SentryOptions *)options
{
    if (![super installWithOptions:options]) {
        return NO;
    }

    self.tracker = [[SentryDependencyContainer sharedInstance] fileIOTracker];
    [self.tracker enable];

    [SentryDependencyContainer.sharedInstance.nsDataSwizzling startWithOptions:options
                                                                       tracker:self.tracker];
    [SentryDependencyContainer.sharedInstance.nsFileManagerSwizzling startWithOptions:options
                                                                              tracker:self.tracker];

    return YES;
}

- (SentryIntegrationOption)integrationOptions
{
    return kIntegrationOptionIsTracingEnabled | kIntegrationOptionEnableAutoPerformanceTracing
        | kIntegrationOptionEnableFileIOTracing;
}

- (void)uninstall
{
    [self.tracker disable];

    [SentryDependencyContainer.sharedInstance.nsDataSwizzling stop];
    [SentryDependencyContainer.sharedInstance.nsFileManagerSwizzling stop];
}

@end
