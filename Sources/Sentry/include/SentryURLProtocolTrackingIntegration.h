#import "SentryIntegrationProtocol.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * This automatically intercepts http requests for performance tracking.
 */
@interface SentryURLProtocolTrackingIntegration : NSObject <SentryIntegrationProtocol>

@end

NS_ASSUME_NONNULL_END
