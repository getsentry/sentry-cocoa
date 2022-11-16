#import <Foundation/Foundation.h>
#import <SentryDependencyContainer.h>
#import <SentryMetricKitIntegration.h>
#import <SentrySwift.h>

@interface
SentryMetricKitIntegration ()

@property (nonatomic, strong) SentryMetricKitManager *metricKitManager;

@end

@implementation SentryMetricKitIntegration

- (BOOL)installWithOptions:(SentryOptions *)options
{
    if (![super installWithOptions:options]) {
        return NO;
    }

    self.metricKitManager = [SentryDependencyContainer sharedInstance].metricKitManager;
    [self.metricKitManager receiveReports];

    return YES;
}

- (SentryIntegrationOption)integrationOptions
{
    return kIntegrationOptionEnableMetricKit;
}

- (void)uninstall
{
    [self.metricKitManager pauseReports];
}

@end
