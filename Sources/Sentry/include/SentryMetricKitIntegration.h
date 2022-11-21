#import "SentryBaseIntegration.h"
#import "SentryIntegrationProtocol.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(ios(14.0), macos(12.0), macCatalyst(14.0))
@interface SentryMetricKitIntegration : SentryBaseIntegration <SentryIntegrationProtocol>

@end

NS_ASSUME_NONNULL_END
