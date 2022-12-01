#import "SentryBaseIntegration.h"
#import "SentryIntegrationProtocol.h"
#import "SentrySwift.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#if SENTRY_HAS_METRIC_KIT

API_AVAILABLE(ios(14.0), macos(12.0), macCatalyst(14.0))
@interface SentryMetricKitIntegration
    : SentryBaseIntegration <SentryIntegrationProtocol, SentryMXManagerDelegate>

@end

#endif

NS_ASSUME_NONNULL_END
