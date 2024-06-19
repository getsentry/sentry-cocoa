#import "SentryBaseIntegration.h"
#import "SentryDefines.h"
#import "SentrySessionReplayIntegration.h"
#import "SentrySwift.h"

#if SENTRY_REPLAY_AVAILABLE

@class SentrySessionReplay;

@interface
SentrySessionReplayIntegration () <SentryIntegrationProtocol>

@property (nonatomic, strong) SentrySessionReplay *sessionReplay;

@end

#endif
