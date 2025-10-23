#import "SentryBaseIntegration.h"
#import "SentrySessionReplayIntegration.h"

#if SENTRY_TARGET_REPLAY_SUPPORTED

@class SentrySessionReplay;
@class SentryViewPhotographer;
@class SentryId;

@interface SentrySessionReplayIntegration ()

@property (nonatomic, strong, nullable) SentrySessionReplay *sessionReplay;

@property (nonatomic, strong) SentryViewPhotographer *_Nonnull viewPhotographer;

@property (nonatomic, readonly, nullable) SentryId *replayId;

- (void)setReplayTags:(NSDictionary<NSString *, id> *_Nonnull)tags;

@end

#endif
