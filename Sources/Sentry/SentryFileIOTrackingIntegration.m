#import "SentryFileIOTrackingIntegration.h"
#import "SentryLog.h"
#import "SentryNSDataSwizzling.h"
#import "SentryOptions.h"

@implementation SentryFileIOTrackingIntegration

- (BOOL)installWithOptions:(SentryOptions *)options
{
    if (![super installWithOptions:options]) {
        return NO;
    }

    [SentryNSDataSwizzling startWithOptions:options];

    return YES;
}

- (SentryIntegrationOption)integrationOptions
{
    return kIntegrationOptionEnableSwizzling | kIntegrationOptionIsTracingEnabled
        | kIntegrationOptionEnableAutoPerformanceTracing | kIntegrationOptionEnableFileIOTracing;
}

- (void)uninstall
{
    [SentryNSDataSwizzling stop];
}

@end
