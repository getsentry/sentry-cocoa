#import "SentryBaseIntegration.h"
#import "SentryIntegrationProtocol.h"
#import "SentrySwift.h"
#import <Foundation/Foundation.h>

#if SENTRY_HAS_METRIC_KIT

NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(ios(14.0), macos(12.0))
API_UNAVAILABLE(tvos, watchos)
@interface SentryMetricKitIntegration
    : SentryBaseIntegration <SentryIntegrationProtocol, SentryMXManagerDelegate>

@end

NS_ASSUME_NONNULL_END

#endif
