#import "SentryCoreDataTrackingIntegration.h"
#import "SentryCoreDataSwizzling.h"
#import "SentryCoreDataTracker.h"
#import "SentryDefaultThreadInspector.h"
#import "SentryLogC.h"
#import "SentryNSDataSwizzling.h"
#import "SentrySwift.h"

@interface SentryCoreDataTrackingIntegration ()

@property (nonatomic, strong) SentryCoreDataTracker *tracker;

@end

@implementation SentryCoreDataTrackingIntegration

- (BOOL)installWithOptions:(SentryOptions *)options
{
    if (![super installWithOptions:options]) {
        return NO;
    }

    self.tracker = [[SentryCoreDataTracker alloc]
        initWithThreadInspector:[[SentryDefaultThreadInspector alloc] initWithOptions:options]
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
