#import "SentryBaseIntegration.h"
#import "SentrySessionReplayIntegration.h"
#import "SentrySwift.h"

#if SENTRY_HAS_UIKIT && !TARGET_OS_VISION

@interface
SentrySessionReplayIntegration () <SentryIntegrationProtocol>

@end

#endif
