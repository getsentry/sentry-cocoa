#import "SentryDelayedFramesTracker.h"

#if SENTRY_HAS_UIKIT

#    import "SentryCurrentDateProvider.h"
#    import "SentryDelayedFrame.h"
#    import "SentryLog.h"
#    import "SentryTime.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryDelayedFramesTracker ()

@property (nonatomic, assign) CFTimeInterval keepDelayedFramesDuration;
@property (nonatomic, strong, readonly) SentryCurrentDateProvider *dateProvider;
@property (nonatomic, strong) NSMutableArray<SentryDelayedFrame *> *delayedFrames;

@end

@implementation SentryDelayedFramesTracker

- (instancetype)initWithKeepDelayedFramesDuration:(CFTimeInterval)keepDelayedFramesDuration
                                     dateProvider:(SentryCurrentDateProvider *)dateProvider
{
    if (self = [super init]) {
        _keepDelayedFramesDuration = keepDelayedFramesDuration;
        _dateProvider = dateProvider;
        [self resetDelayedFramesTimeStamps];
    }
    return self;
}

- (void)resetDelayedFramesTimeStamps
{
    _delayedFrames = [NSMutableArray array];
    SentryDelayedFrame *initialFrame =
        [[SentryDelayedFrame alloc] initWithStartTimestamp:[self.dateProvider systemTime]
                                          expectedDuration:0
                                            actualDuration:0];
    [_delayedFrames addObject:initialFrame];
}

- (void)recordDelayedFrame:(uint64_t)startSystemTimestamp
          expectedDuration:(CFTimeInterval)expectedDuration
            actualDuration:(CFTimeInterval)actualDuration
{
    @synchronized(self.delayedFrames) {
        [self removeOldDelayedFrames];

        SENTRY_LOG_DEBUG(@"FrameDelay: Record expected:%f ms actual %f ms", expectedDuration * 1000,
            actualDuration * 1000);
        SentryDelayedFrame *delayedFrame =
            [[SentryDelayedFrame alloc] initWithStartTimestamp:startSystemTimestamp
                                              expectedDuration:expectedDuration
                                                actualDuration:actualDuration];
        [self.delayedFrames addObject:delayedFrame];
    }
}

/**
 * Removes delayed frame that are older than current time minus `keepDelayedFramesDuration`.
 * @note Make sure to call this in a @synchronized block.
 */
- (void)removeOldDelayedFrames
{
    u_int64_t transactionMaxDurationNS = timeIntervalToNanoseconds(_keepDelayedFramesDuration);

    uint64_t removeFramesBeforeSystemTimeStamp
        = _dateProvider.systemTime - transactionMaxDurationNS;
    if (_dateProvider.systemTime < transactionMaxDurationNS) {
        removeFramesBeforeSystemTimeStamp = 0;
    }

    NSInteger i = 0;
    for (SentryDelayedFrame *frame in self.delayedFrames) {
        uint64_t frameEndSystemTimeStamp
            = frame.startSystemTimestamp + timeIntervalToNanoseconds(frame.actualDuration);
        if (frameEndSystemTimeStamp < removeFramesBeforeSystemTimeStamp) {
            i++;
        } else {
            break;
        }
    }
    [self.delayedFrames removeObjectsInRange:NSMakeRange(0, i)];
}

- (CFTimeInterval)getFramesDelay:(uint64_t)startSystemTimestamp
              endSystemTimestamp:(uint64_t)endSystemTimestamp
                       isRunning:(BOOL)isRunning
              thisFrameTimestamp:(CFTimeInterval)thisFrameTimestamp
          previousFrameTimestamp:(CFTimeInterval)previousFrameTimestamp
              slowFrameThreshold:(CFTimeInterval)slowFrameThreshold
{
    CFTimeInterval cantCalculateFrameDelayReturnValue = -1.0;

    if (isRunning == NO) {
        SENTRY_LOG_DEBUG(@"Not calculating frames delay because frames tracker isn't running.");
        return cantCalculateFrameDelayReturnValue;
    }

    if (startSystemTimestamp >= endSystemTimestamp) {
        SENTRY_LOG_DEBUG(@"Not calculating frames delay because startSystemTimestamp is before  "
                         @"endSystemTimestamp");
        return cantCalculateFrameDelayReturnValue;
    }

    if (endSystemTimestamp > self.dateProvider.systemTime) {
        SENTRY_LOG_DEBUG(
            @"Not calculating frames delay because endSystemTimestamp is in the future.");
        return cantCalculateFrameDelayReturnValue;
    }

    NSArray<SentryDelayedFrame *> *frames;
    @synchronized(self.delayedFrames) {
        uint64_t oldestDelayedFrameStartTimestamp = UINT64_MAX;
        SentryDelayedFrame *oldestDelayedFrame = self.delayedFrames.firstObject;
        if (oldestDelayedFrame != nil) {
            oldestDelayedFrameStartTimestamp = oldestDelayedFrame.startSystemTimestamp;
        }

        if (oldestDelayedFrameStartTimestamp > startSystemTimestamp) {
            SENTRY_LOG_DEBUG(@"Not calculating frames delay because the record of delayed frames "
                             @"doesn't go back enough in time.");
            return cantCalculateFrameDelayReturnValue;
        }

        // Copy as late as possible to avoid allocating unnecessary memory.
        frames = self.delayedFrames.copy;
    }

    // Check if there is an delayed frame going on but not recorded yet.
    CFTimeInterval frameDuration = thisFrameTimestamp - previousFrameTimestamp;
    CFTimeInterval ongoingDelayedFrame = 0.0;
    if (frameDuration > slowFrameThreshold) {
        ongoingDelayedFrame = frameDuration - slowFrameThreshold;
    }

    CFTimeInterval delay = ongoingDelayedFrame;

    // Iterate in reverse order, as younger frame delays are more likely to match the queried
    // period.
    for (SentryDelayedFrame *frame in frames.reverseObjectEnumerator) {

        uint64_t frameEndSystemTimeStamp
            = frame.startSystemTimestamp + timeIntervalToNanoseconds(frame.actualDuration);
        if (frameEndSystemTimeStamp < startSystemTimestamp) {
            break;
        }

        NSDate *startDate = [NSDate
            dateWithTimeIntervalSinceReferenceDate:nanosecondsToTimeInterval(startSystemTimestamp)];
        NSDate *endDate = [NSDate
            dateWithTimeIntervalSinceReferenceDate:nanosecondsToTimeInterval(endSystemTimestamp)];

        CFTimeInterval delayStartTime
            = nanosecondsToTimeInterval(frame.startSystemTimestamp) + frame.expectedDuration;
        NSDate *frameDelayStartDate =
            [NSDate dateWithTimeIntervalSinceReferenceDate:delayStartTime];

        NSDateInterval *frameDelayDateInterval = [[NSDateInterval alloc] initWithStartDate:startDate
                                                                                   endDate:endDate];

        // Only use the date interval for the actual delay
        NSDateInterval *frameDateInterval = [[NSDateInterval alloc]
            initWithStartDate:frameDelayStartDate
                     duration:(frame.actualDuration - frame.expectedDuration)];

        if ([frameDelayDateInterval intersectsDateInterval:frameDateInterval]) {
            NSDateInterval *intersection =
                [frameDelayDateInterval intersectionWithDateInterval:frameDateInterval];
            delay = delay + intersection.duration;
        }
    }

    return delay;
}

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
