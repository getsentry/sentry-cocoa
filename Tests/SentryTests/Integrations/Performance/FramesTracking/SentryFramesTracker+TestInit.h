#import "SentryDefines.h"
#import "SentryFramesTracker.h"

NS_ASSUME_NONNULL_BEGIN

#if SENTRY_HAS_UIKIT
SENTRY_EXTERN double slowFrameThreshold(uint64_t actualFramesPerSecond);
SENTRY_EXTERN CFTimeInterval const SentryFrozenFrameThreshold;

@interface
SentryFramesTracker (TestInit)

- (instancetype)initWithDisplayLinkWrapper:(SentryDisplayLinkWrapper *)displayLinkWrapper;

- (void)setDisplayLinkWrapper:(SentryDisplayLinkWrapper *)displayLinkWrapper;

- (void)resetFrames;

@end
#endif

NS_ASSUME_NONNULL_END
