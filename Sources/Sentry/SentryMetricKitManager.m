#import <Foundation/Foundation.h>
#import <MetricKit/MetricKit.h>
#import <SentryMetricKitManager.h>

@implementation SentryMetricKitManager

- (void)receiveReports
{
    [[MXMetricManager sharedManager] addSubscriber:self];
}

- (void)pauseReports
{
    [[MXMetricManager sharedManager] removeSubscriber:self];
}

- (void)didReceiveDiagnosticPayloads:(NSArray<MXDiagnosticPayload *> *)payloads
{
}

@end
