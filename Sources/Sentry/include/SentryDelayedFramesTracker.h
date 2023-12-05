#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT

@class SentryDisplayLinkWrapper;
@class SentryCurrentDateProvider;

NS_ASSUME_NONNULL_BEGIN

@interface SentryDelayedFramesTracker : NSObject
SENTRY_NO_INIT

- (instancetype)initWithKeepDelayedFramesDuration:(CFTimeInterval)keepDelayedFramesDuration
                                     dateProvider:(SentryCurrentDateProvider *)dateProvider;

- (void)resetDelayedFramesTimeStamps;

- (void)recordDelayedFrame:(uint64_t)startSystemTimestamp
          expectedDuration:(CFTimeInterval)expectedDuration
            actualDuration:(CFTimeInterval)actualDuration;

- (CFTimeInterval)getFramesDelay:(uint64_t)startSystemTimestamp
              endSystemTimestamp:(uint64_t)endSystemTimestamp
                       isRunning:(BOOL)isRunning
              thisFrameTimestamp:(CFTimeInterval)thisFrameTimestamp
          previousFrameTimestamp:(CFTimeInterval)previousFrameTimestamp
              slowFrameThreshold:(CFTimeInterval)slowFrameThreshold;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
