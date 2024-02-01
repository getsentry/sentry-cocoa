#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT

#    import "SentryProfilingConditionals.h"

@class SentryOptions, SentryDisplayLinkWrapper, SentryScreenFrames;
@class SentryCurrentDateProvider;
@class SentryDispatchQueueWrapper;

NS_ASSUME_NONNULL_BEGIN

@class SentryTracer;

@protocol SentryFramesTrackerListener

- (void)framesTrackerHasNewFrame:(NSDate *)newFrameDate;

@end

/**
 * Tracks total, frozen and slow frames for iOS, tvOS, and Mac Catalyst.
 */
@interface SentryFramesTracker : NSObject

- (instancetype)initWithDisplayLinkWrapper:(SentryDisplayLinkWrapper *)displayLinkWrapper
                              dateProvider:(SentryCurrentDateProvider *)dateProvider
                      dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
                 keepDelayedFramesDuration:(CFTimeInterval)keepDelayedFramesDuration;

@property (nonatomic, assign, readonly) SentryScreenFrames *currentFrames;
@property (nonatomic, assign, readonly) BOOL isRunning;

#    if SENTRY_TARGET_PROFILING_SUPPORTED
/** Remove previously recorded timestamps in preparation for a later profiled transaction. */
- (void)resetProfilingTimestamps;
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED

- (void)start;
- (void)stop;

/*
 * Returns the frames delay for the passed time period. If the method can't calculate the frames
 * delay, it returns -1.
 */
- (CFTimeInterval)getFramesDelay:(uint64_t)startSystemTimestamp
              endSystemTimestamp:(uint64_t)endSystemTimestamp;

- (void)addListener:(id<SentryFramesTrackerListener>)listener;

- (void)removeListener:(id<SentryFramesTrackerListener>)listener;

@end

BOOL sentryShouldAddSlowFrozenFramesData(
    NSInteger totalFrames, NSInteger slowFrames, NSInteger frozenFrames);

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
