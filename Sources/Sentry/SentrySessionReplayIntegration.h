#import "SentryBaseIntegration.h"
#import "SentrySwift.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
#if SENTRY_HAS_UIKIT && !TARGET_OS_VISION
@interface SentrySessionReplayIntegration : SentryBaseIntegration <SentryIntegrationProtocol>

@end
#endif
NS_ASSUME_NONNULL_END
