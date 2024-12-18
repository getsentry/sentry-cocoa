#import "SentryFileIOTrackingIntegration.h"
#import "SentryDependencyContainer.h"
#import "SentryFileIOTracker.h"
#import "SentryNSDataSwizzling.h"
#import "SentryNSFileManagerSwizzling.h"
#import "SentryThreadInspector.h"

@interface SentryFileIOTrackingIntegration ()

@property (nonatomic, strong) SentryFileIOTracker *tracker;

@end

@implementation SentryFileIOTrackingIntegration

- (BOOL)installWithOptions:(SentryOptions *)options
{
    if (![super installWithOptions:options]) {
        return NO;
    }

    self.tracker = [[SentryFileIOTracker alloc]
        initWithThreadInspector:[[SentryThreadInspector alloc] initWithOptions:options]
             processInfoWrapper:[SentryDependencyContainer.sharedInstance processInfoWrapper]];
    [self.tracker enable];

    [SentryNSDataSwizzling.shared startWithOptions:options tracker:self.tracker];
    [SentryNSFileManagerSwizzling.shared startWithOptions:options tracker:self.tracker];

    return YES;
}

- (SentryIntegrationOption)integrationOptions
{
    return kIntegrationOptionEnableSwizzling | kIntegrationOptionIsTracingEnabled
        | kIntegrationOptionEnableAutoPerformanceTracing | kIntegrationOptionEnableFileIOTracing;
}

- (void)uninstall
{
    [self.tracker disable];
}

@end
