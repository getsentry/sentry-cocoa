#import "SentryFramesTracker.h"

#if SENTRY_HAS_UIKIT

#    import "SentryCompiler.h"
#    import "SentryCurrentDateProvider.h"
#    import "SentryDelayedFrame.h"
#    import "SentryDisplayLinkWrapper.h"
#    import "SentryLog.h"
#    import "SentryProfiler.h"
#    import "SentryProfilingConditionals.h"
#    import "SentryTime.h"
#    import "SentryTracer.h"
#    import <SentryScreenFrames.h>
#    include <stdatomic.h>

#    if SENTRY_TARGET_PROFILING_SUPPORTED
/** A mutable version of @c SentryFrameInfoTimeSeries so we can accumulate results. */
typedef NSMutableArray<NSDictionary<NSString *, NSNumber *> *> SentryMutableFrameInfoTimeSeries;
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED

static CFTimeInterval const SentryFrozenFrameThreshold = 0.7;
static CFTimeInterval const SentryPreviousFrameInitialValue = -1;

@interface
SentryFramesTracker ()

@property (nonatomic, strong, readonly) SentryDisplayLinkWrapper *displayLinkWrapper;
@property (nonatomic, strong, readonly) SentryCurrentDateProvider *dateProvider;
@property (nonatomic, assign) CFTimeInterval previousFrameTimestamp;
@property (nonatomic) uint64_t previousFrameSystemTimestamp;
@property (nonatomic) uint64_t currentFrameRate;
@property (nonatomic, strong) NSHashTable<id<SentryFramesTrackerListener>> *listeners;
#    if SENTRY_TARGET_PROFILING_SUPPORTED
@property (nonatomic, readwrite) SentryMutableFrameInfoTimeSeries *frozenFrameTimestamps;
@property (nonatomic, readwrite) SentryMutableFrameInfoTimeSeries *slowFrameTimestamps;
@property (nonatomic, readwrite) SentryMutableFrameInfoTimeSeries *frameRateTimestamps;
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED

@property (nonatomic, strong) NSMutableArray<SentryDelayedFrame *> *delayedFrames;
@property (nonatomic) uint8_t delayedFrameWriteIndex;

@end

CFTimeInterval
slowFrameThreshold(uint64_t actualFramesPerSecond)
{
    // Most frames take just a few microseconds longer than the optimal calculated duration.
    // Therefore we subtract one, because otherwise almost all frames would be slow.
    return 1.0 / (actualFramesPerSecond - 1.0);
}

@implementation SentryFramesTracker {
    unsigned int _totalFrames;
    unsigned int _slowFrames;
    unsigned int _frozenFrames;
}

- (instancetype)initWithDisplayLinkWrapper:(SentryDisplayLinkWrapper *)displayLinkWrapper
                              dateProvider:(SentryCurrentDateProvider *)dateProvider;
{
    if (self = [super init]) {
        _isRunning = NO;
        _displayLinkWrapper = displayLinkWrapper;
        _dateProvider = dateProvider;
        _listeners = [NSHashTable weakObjectsHashTable];

        _currentFrameRate = 60;
        [self resetFrames];
        SENTRY_LOG_DEBUG(@"Initialized frame tracker %@", self);
    }
    return self;
}

/** Internal for testing */
- (void)setDisplayLinkWrapper:(SentryDisplayLinkWrapper *)displayLinkWrapper
{
    _displayLinkWrapper = displayLinkWrapper;
}

/** Internal for testing */
- (void)resetFrames
{
    _totalFrames = 0;
    _frozenFrames = 0;
    _slowFrames = 0;

    self.previousFrameTimestamp = SentryPreviousFrameInitialValue;
#    if SENTRY_TARGET_PROFILING_SUPPORTED
    [self resetProfilingTimestamps];
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED

    [self resetDelayedFramesTimeStamps];
}

#    if SENTRY_TARGET_PROFILING_SUPPORTED
- (void)resetProfilingTimestamps
{
    self.frozenFrameTimestamps = [SentryMutableFrameInfoTimeSeries array];
    self.slowFrameTimestamps = [SentryMutableFrameInfoTimeSeries array];
    self.frameRateTimestamps = [SentryMutableFrameInfoTimeSeries array];
}
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED

- (void)resetDelayedFramesTimeStamps
{
    _delayedFrames = [NSMutableArray array];
    SentryDelayedFrame *initialFrame =
        [[SentryDelayedFrame alloc] initWithStartTimestamp:[self.dateProvider systemTime]
                                          expectedDuration:0
                                            actualDuration:0];
    [_delayedFrames addObject:initialFrame];
    _delayedFrameWriteIndex = 1;
}

- (void)start
{
    if (_isRunning) {
        return;
    }

    _isRunning = YES;

    [_displayLinkWrapper linkWithTarget:self selector:@selector(displayLinkCallback)];
}

- (void)displayLinkCallback
{
    CFTimeInterval thisFrameTimestamp = self.displayLinkWrapper.timestamp;
    uint64_t thisFrameSystemTimestamp = self.dateProvider.systemTime;

    if (self.previousFrameTimestamp == SentryPreviousFrameInitialValue) {
        self.previousFrameTimestamp = thisFrameTimestamp;
        self.previousFrameSystemTimestamp = thisFrameSystemTimestamp;
        [self reportNewFrame];
        return;
    }

    // Calculate the actual frame rate as pointed out by the Apple docs:
    // https://developer.apple.com/documentation/quartzcore/cadisplaylink?language=objc The actual
    // frame rate can change at any time by setting preferredFramesPerSecond or due to ProMotion
    // display, low power mode, critical thermal state, and accessibility settings. Therefore we
    // need to check the frame rate for every callback.
    // targetTimestamp is only available on iOS 10.0 and tvOS 10.0 and above. We use a fallback of
    // 60 fps.
    _currentFrameRate = 60;
    if (UNLIKELY((self.displayLinkWrapper.targetTimestamp == self.displayLinkWrapper.timestamp))) {
        _currentFrameRate = 60;
    } else {
        _currentFrameRate = (uint64_t)round(
            (1 / (self.displayLinkWrapper.targetTimestamp - self.displayLinkWrapper.timestamp)));
    }

#    if SENTRY_TARGET_PROFILING_SUPPORTED
    if ([SentryProfiler isCurrentlyProfiling]) {
        BOOL hasNoFrameRatesYet = self.frameRateTimestamps.count == 0;
        uint64_t previousFrameRate
            = self.frameRateTimestamps.lastObject[@"value"].unsignedLongLongValue;
        BOOL frameRateChanged = previousFrameRate != _currentFrameRate;
        BOOL shouldRecordNewFrameRate = hasNoFrameRatesYet || frameRateChanged;
        if (shouldRecordNewFrameRate) {
            SENTRY_LOG_DEBUG(@"Recording new frame rate at %llu.", thisFrameSystemTimestamp);
            [self recordTimestamp:thisFrameSystemTimestamp
                            value:@(_currentFrameRate)
                            array:self.frameRateTimestamps];
        }
    }
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED

    CFTimeInterval frameDuration = thisFrameTimestamp - self.previousFrameTimestamp;

    if (frameDuration > slowFrameThreshold(_currentFrameRate)
        && frameDuration <= SentryFrozenFrameThreshold) {
        _slowFrames++;
#    if SENTRY_TARGET_PROFILING_SUPPORTED
        SENTRY_LOG_DEBUG(@"Capturing slow frame starting at %llu (frame tracker: %@).",
            thisFrameSystemTimestamp, self);
        [self recordTimestamp:thisFrameSystemTimestamp
                        value:@(thisFrameSystemTimestamp - self.previousFrameSystemTimestamp)
                        array:self.slowFrameTimestamps];
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED
    } else if (frameDuration > SentryFrozenFrameThreshold) {
        _frozenFrames++;
#    if SENTRY_TARGET_PROFILING_SUPPORTED
        SENTRY_LOG_DEBUG(@"Capturing frozen frame starting at %llu.", thisFrameSystemTimestamp);
        [self recordTimestamp:thisFrameSystemTimestamp
                        value:@(thisFrameSystemTimestamp - self.previousFrameSystemTimestamp)
                        array:self.frozenFrameTimestamps];
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED
    }

    if (frameDuration > slowFrameThreshold(_currentFrameRate)) {
        [self recordDelayedFrame:self.previousFrameSystemTimestamp
                expectedDuration:slowFrameThreshold(_currentFrameRate)
                  actualDuration:frameDuration];
    }

    _totalFrames++;
    self.previousFrameTimestamp = thisFrameTimestamp;
    self.previousFrameSystemTimestamp = thisFrameSystemTimestamp;
    [self reportNewFrame];
}

- (void)reportNewFrame
{
    NSArray *localListeners;
    @synchronized(self.listeners) {
        localListeners = [self.listeners allObjects];
    }

    for (id<SentryFramesTrackerListener> listener in localListeners) {
        [listener framesTrackerHasNewFrame];
    }
}

#    if SENTRY_TARGET_PROFILING_SUPPORTED
- (void)recordTimestamp:(uint64_t)timestamp value:(NSNumber *)value array:(NSMutableArray *)array
{
    BOOL shouldRecord = [SentryProfiler isCurrentlyProfiling];
#        if defined(TEST) || defined(TESTCI)
    shouldRecord = YES;
#        endif // defined(TEST) || defined(TESTCI)
    if (shouldRecord) {
        [array addObject:@{ @"timestamp" : @(timestamp), @"value" : value }];
    }
}
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED

- (SentryScreenFrames *)currentFrames
{
#    if SENTRY_TARGET_PROFILING_SUPPORTED
    return [[SentryScreenFrames alloc] initWithTotal:_totalFrames
                                              frozen:_frozenFrames
                                                slow:_slowFrames
                                 slowFrameTimestamps:self.slowFrameTimestamps
                               frozenFrameTimestamps:self.frozenFrameTimestamps
                                 frameRateTimestamps:self.frameRateTimestamps];
#    else
    return [[SentryScreenFrames alloc] initWithTotal:_totalFrames
                                              frozen:_frozenFrames
                                                slow:_slowFrames];
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED
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
 * Removes delayed frame that are older than current time minus
 * SENTRY_AUTO_TRANSACTION_MAX_DURATION.
 * @note Make sure to call this in a @synchronized block.
 */
- (void)removeOldDelayedFrames
{
    u_int64_t transactionMaxDurationNS
        = timeIntervalToNanoseconds(SENTRY_AUTO_TRANSACTION_MAX_DURATION);

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

- (CFTimeInterval)getFrameDelay:(uint64_t)startSystemTimestamp
             endSystemTimestamp:(uint64_t)endSystemTimestamp
{
    CFTimeInterval cantCalculateFrameDelay = -1.0;

    if (_isRunning == NO) {
        SENTRY_LOG_DEBUG(@"Not calculating frames delay because frames tracker isn't running.");
        return cantCalculateFrameDelay;
    }

    if (startSystemTimestamp >= endSystemTimestamp) {
        SENTRY_LOG_DEBUG(@"Not calculating frames delay because startSystemTimestamp is before  "
                         @"endSystemTimestamp");
        return cantCalculateFrameDelay;
    }

    if (endSystemTimestamp > self.dateProvider.systemTime) {
        SENTRY_LOG_DEBUG(@"Not calculating frames delay endSystemTimestamp is in the future.");
        return cantCalculateFrameDelay;
    }

    // Check if there is an delayed frame going on but not recorded yet.
    CFTimeInterval thisFrameTimestamp = self.displayLinkWrapper.timestamp;
    CFTimeInterval frameDuration = thisFrameTimestamp - self.previousFrameTimestamp;
    CFTimeInterval ongoingDelayedFrame = 0.0;
    if (frameDuration > slowFrameThreshold(_currentFrameRate)) {
        ongoingDelayedFrame = frameDuration - slowFrameThreshold(_currentFrameRate);
    }

    CFTimeInterval delay = ongoingDelayedFrame;

    @synchronized(self.delayedFrames) {

        // Although we use a ring buffer, and it could take a while until we get to frames within
        // the time interval for which we want to return frame delay, we don't want to use a normal
        // for loop with accessing the elements by index because NSFastEnumeration is faster than a
        // normal for loop and in the worst case we need to iterate over all elements anyways. A
        // binary search to find the first and last delayed frame in our time interval doesn't help
        // either because, again, we need to iterate over all elements in the worst case.

        uint64_t oldestDelayedFrameStartTimestamp = UINT64_MAX;

        for (SentryDelayedFrame *frame in self.delayedFrames) {
            if (frame.startSystemTimestamp < oldestDelayedFrameStartTimestamp) {
                oldestDelayedFrameStartTimestamp = frame.startSystemTimestamp;
            }
        }

        if (oldestDelayedFrameStartTimestamp > startSystemTimestamp) {
            return cantCalculateFrameDelay;
        }

        for (SentryDelayedFrame *frame in self.delayedFrames) {
            NSDate *startDate =
                [NSDate dateWithTimeIntervalSinceReferenceDate:nanosecondsToTimeInterval(
                                                                   startSystemTimestamp)];
            NSDate *endDate =
                [NSDate dateWithTimeIntervalSinceReferenceDate:nanosecondsToTimeInterval(
                                                                   endSystemTimestamp)];

            CFTimeInterval delayStartTime
                = nanosecondsToTimeInterval(frame.startSystemTimestamp) + frame.expectedDuration;
            NSDate *frameDelayStartDate =
                [NSDate dateWithTimeIntervalSinceReferenceDate:delayStartTime];

            NSDateInterval *frameDelayDateInterval =
                [[NSDateInterval alloc] initWithStartDate:startDate endDate:endDate];

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
    }
    return delay;
}

- (void)addListener:(id<SentryFramesTrackerListener>)listener
{

    @synchronized(self.listeners) {
        [self.listeners addObject:listener];
    }
}

- (void)removeListener:(id<SentryFramesTrackerListener>)listener
{
    @synchronized(self.listeners) {
        [self.listeners removeObject:listener];
    }
}

- (void)stop
{
    _isRunning = NO;
    [self.displayLinkWrapper invalidate];
    [self resetDelayedFramesTimeStamps];
}

- (void)dealloc
{
    [self stop];
}

@end

BOOL
sentryShouldAddSlowFrozenFramesData(
    NSInteger totalFrames, NSInteger slowFrames, NSInteger frozenFrames)
{
    BOOL allBiggerThanZero = totalFrames >= 0 && slowFrames >= 0 && frozenFrames >= 0;
    BOOL oneBiggerThanZero = totalFrames > 0 || slowFrames > 0 || frozenFrames > 0;

    return allBiggerThanZero && oneBiggerThanZero;
}

#endif // SENTRY_HAS_UIKIT
