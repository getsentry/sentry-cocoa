#import "SentryDefines.h"
#import <MetricKit/MetricKit.h>

API_AVAILABLE(ios(14.0), macos(12.0), macCatalyst(14.0))
@interface SentryMetricKitManager : NSObject <MXMetricManagerSubscriber>

- (void)receiveReports;

- (void)pauseReports;

@end
