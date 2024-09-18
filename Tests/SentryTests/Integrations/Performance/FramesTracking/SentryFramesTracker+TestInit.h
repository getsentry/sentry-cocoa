#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT

#    import "SentryFramesTracker.h"

NS_ASSUME_NONNULL_BEGIN

SENTRY_EXTERN double slowFrameThreshold(uint64_t actualFramesPerSecond);
SENTRY_EXTERN CFTimeInterval const SentryFrozenFrameThreshold;

@interface
SentryFramesTracker (TestInit)

- (instancetype)initWithDisplayLinkWrapper:(SentryDisplayLinkWrapper *)displayLinkWrapper;

- (void)setDisplayLinkWrapper:(SentryDisplayLinkWrapper *)displayLinkWrapper;

- (void)resetFrames;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
