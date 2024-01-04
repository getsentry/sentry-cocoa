#import "SentryCoreDataTrackingIntegration.h"
#import "SentryCoreDataSwizzling.h"
#import "SentryCoreDataTracker.h"
#import "SentryDependencyContainer.h"
#import "SentryLog.h"
#import "SentryNSDataSwizzling.h"
#import "SentryNSProcessInfoWrapper.h"
#import "SentryOptions.h"
#import "SentryThreadInspector.h"

@interface
SentryCoreDataTrackingIntegration ()

@property (nonatomic, strong) SentryCoreDataTracker *tracker;

@end

@implementation SentryCoreDataTrackingIntegration

+ (void)load
{
    NSLog(@"%llu %s", clock_gettime_nsec_np(CLOCK_UPTIME_RAW), __PRETTY_FUNCTION__);
}

- (BOOL)installWithOptions:(SentryOptions *)options
{
    if (![super installWithOptions:options]) {
        return NO;
    }

    self.tracker = [[SentryCoreDataTracker alloc]
        initWithThreadInspector:[[SentryThreadInspector alloc] initWithOptions:options]
             processInfoWrapper:[SentryDependencyContainer.sharedInstance processInfoWrapper]];
    [SentryCoreDataSwizzling.sharedInstance startWithTracker:self.tracker];

    return YES;
}

- (SentryIntegrationOption)integrationOptions
{
    return kIntegrationOptionEnableAutoPerformanceTracing | kIntegrationOptionEnableSwizzling
        | kIntegrationOptionIsTracingEnabled | kIntegrationOptionEnableCoreDataTracing;
}

- (void)uninstall
{
    [SentryCoreDataSwizzling.sharedInstance stop];
}

@end
