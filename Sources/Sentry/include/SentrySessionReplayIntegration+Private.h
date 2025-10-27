#import "SentrySessionReplayIntegration.h"

NS_ASSUME_NONNULL_BEGIN
#if SENTRY_TARGET_REPLAY_SUPPORTED

@class SentrySessionReplay;
@class SentryViewPhotographer;
@class SentryId;

@interface SentrySessionReplayIntegration ()

@property (nonatomic, strong, nullable) SentrySessionReplay *sessionReplay;

@property (nonatomic, strong) SentryViewPhotographer *viewPhotographer;

@property (nonatomic, readonly, nullable) SentryId *replayId;

- (void)setReplayTags:(NSDictionary<NSString *, id> *)tags;

@end

#endif
NS_ASSUME_NONNULL_END
