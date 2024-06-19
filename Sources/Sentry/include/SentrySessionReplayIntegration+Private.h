#import "SentryBaseIntegration.h"
#import "SentryDefines.h"
#import "SentrySessionReplayIntegration.h"
#import "SentrySwift.h"

#if SENTRY_TARGET_REPLAY_SUPPORTED

@class SentrySessionReplay;

@interface
SentrySessionReplayIntegration () <SentryIntegrationProtocol>

@property (nonatomic, strong) SentrySessionReplay *sessionReplay;

@end

#endif
