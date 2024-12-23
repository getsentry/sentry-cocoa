#import "SentryBaseIntegration.h"
#import "SentrySessionReplayIntegration.h"
#import "SentrySwift.h"

#if SENTRY_TARGET_REPLAY_SUPPORTED

NS_ASSUME_NONNULL_BEGIN

@class SentrySessionReplay;
@class SentryViewPhotographer;

@interface SentrySessionReplayIntegration () <SentryIntegrationProtocol, SentrySessionListener,
    SentrySessionReplayDelegate>

@property (nonatomic, strong, nullable) SentrySessionReplay *sessionReplay;

@property (nonatomic, strong) SentryViewPhotographer *viewPhotographer;

@property (nonatomic, strong, nullable) NSDictionary<NSString *, id> *sdkInfo;

@end

NS_ASSUME_NONNULL_END

#endif
