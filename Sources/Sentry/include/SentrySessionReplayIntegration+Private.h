#import "SentryBaseIntegration.h"
#import "SentrySessionReplayIntegration.h"
#import "SentrySwift.h"

#if SENTRY_HAS_UIKIT && !TARGET_OS_VISION

@class SentrySessionReplay;

@interface
SentrySessionReplayIntegration () <SentryIntegrationProtocol, SentrySessionListener>

@property (nonatomic, strong) SentrySessionReplay *sessionReplay;

@end

#endif
