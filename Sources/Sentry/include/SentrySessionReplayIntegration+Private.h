#import "SentryBaseIntegration.h"
#import "SentrySessionReplayIntegration.h"
#import "SentrySwift.h"

#if SENTRY_TARGET_REPLAY_SUPPORTED

@class SentrySessionReplay;
@class SentryViewPhotographer;

@interface SentrySessionReplayIntegration () <SentrySessionListener, SentrySessionReplayDelegate>

@property (nonatomic, strong) SentrySessionReplay *sessionReplay;

@property (nonatomic, strong) SentryViewPhotographer *viewPhotographer;

- (void)setReplayTags:(NSDictionary<NSString *, id> *)tags;

@end

#endif
