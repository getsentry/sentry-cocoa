#import "SentryFramesTracker.h"
#import "SentryCompiler.h"
#import "SentryCurrentDate.h"
#import "SentryDisplayLinkWrapper.h"
#import "SentryLog.h"
#import "SentryProfiler.h"
#import "SentryProfilingConditionals.h"
#import "SentryTime.h"
#import "SentryTracer.h"
#import <SentryScreenFrames.h>
#include <stdatomic.h>

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>

#    if SENTRY_TARGET_PROFILING_SUPPORTED
/** A mutable version of @c SentryFrameInfoTimeSeries so we can accumulate results. */
typedef NSMutableArray<NSDictionary<NSString *, NSNumber *> *> SentryMutableFrameInfoTimeSeries;
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED

CFTimeInterval const SentryFrozenFrameThreshold = 0.7;
static CFTimeInterval const SentryPreviousFrameInitialValue = -1;

/**
 * Relaxed memoring ordering is typical for incrementing counters. This operation only requires
 * atomicity but not ordering or synchronization.
 */
static memory_order const SentryFramesMemoryOrder = memory_order_relaxed;

@interface
SentryFramesTracker ()

@property (nonatomic, strong, readonly) SentryDisplayLinkWrapper *displayLinkWrapper;
@property (nonatomic, assign) CFTimeInterval previousFrameTimestamp;
@property (nonatomic) uint64_t previousFrameSystemTimestamp;
@property (nonatomic, strong) NSHashTable<id<SentryFramesTrackerListener>> *listeners;
#    if SENTRY_TARGET_PROFILING_SUPPORTED
@property (nonatomic, readwrite) SentryMutableFrameInfoTimeSeries *frozenFrameTimestamps;
@property (nonatomic, readwrite) SentryMutableFrameInfoTimeSeries *slowFrameTimestamps;
@property (nonatomic, readwrite) SentryMutableFrameInfoTimeSeries *frameRateTimestamps;
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED

@end

CFTimeInterval
slowFrameThreshold(uint64_t actualFramesPerSecond)
{
    // Most frames take just a few microseconds longer than the optimal calculated duration.
    // Therefore we subtract one, because otherwise almost all frames would be slow.
    return 1.0 / (actualFramesPerSecond - 1.0);
}

@implementation SentryFramesTracker {

    /**
     * With 32 bit we can track frames with 120 fps for around 414 days (2^32 / (120* 60 * 60 *
     * 24)).
     */
    atomic_uint_fast32_t _totalFrames;
    atomic_uint_fast32_t _slowFrames;
    atomic_uint_fast32_t _frozenFrames;
}

+ (instancetype)sharedInstance
{
    static SentryFramesTracker *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance =
            [[self alloc] initWithDisplayLinkWrapper:[[SentryDisplayLinkWrapper alloc] init]];
    });
    return sharedInstance;
}

/** Internal constructor for testing */
- (instancetype)initWithDisplayLinkWrapper:(SentryDisplayLinkWrapper *)displayLinkWrapper
{
    if (self = [super init]) {
        _isRunning = NO;
        _displayLinkWrapper = displayLinkWrapper;
        _listeners = [NSHashTable weakObjectsHashTable];
        [self resetFrames];
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
    atomic_store_explicit(&_totalFrames, 0, SentryFramesMemoryOrder);
    atomic_store_explicit(&_frozenFrames, 0, SentryFramesMemoryOrder);
    atomic_store_explicit(&_slowFrames, 0, SentryFramesMemoryOrder);

    self.previousFrameTimestamp = SentryPreviousFrameInitialValue;
#    if SENTRY_TARGET_PROFILING_SUPPORTED
    [self resetProfilingTimestamps];
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED
}

#    if SENTRY_TARGET_PROFILING_SUPPORTED
- (void)resetProfilingTimestamps
{
    self.frozenFrameTimestamps = [SentryMutableFrameInfoTimeSeries array];
    self.slowFrameTimestamps = [SentryMutableFrameInfoTimeSeries array];
    self.frameRateTimestamps = [SentryMutableFrameInfoTimeSeries array];
}
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED

- (void)start
{
    _isRunning = YES;
    [_displayLinkWrapper linkWithTarget:self selector:@selector(displayLinkCallback)];
}

- (void)displayLinkCallback
{
    CFTimeInterval thisFrameTimestamp = self.displayLinkWrapper.timestamp;
    uint64_t thisFrameSystemTimestamp = SentryCurrentDate.getCurrentDateProvider.systemTime;

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
    uint64_t currentFrameRate = 60;
    if (UNLIKELY((self.displayLinkWrapper.targetTimestamp == self.displayLinkWrapper.timestamp))) {
        currentFrameRate = 60;
    } else {
        currentFrameRate = (uint64_t)round(
            (1 / (self.displayLinkWrapper.targetTimestamp - self.displayLinkWrapper.timestamp)));
    }

#    if SENTRY_TARGET_PROFILING_SUPPORTED
#        if defined(TEST) || defined(TESTCI)
    BOOL shouldRecordFrameRates = YES;
#        else
    BOOL shouldRecordFrameRates = [SentryProfiler isRunning];
#        endif // defined(TEST) || defined(TESTCI)
    BOOL hasNoFrameRatesYet = self.frameRateTimestamps.count == 0;
    uint64_t previousFrameRate
        = self.frameRateTimestamps.lastObject[@"frame_rate"].unsignedLongLongValue;
    BOOL frameRateChanged = previousFrameRate != currentFrameRate;
    BOOL shouldRecordNewFrameRate
        = shouldRecordFrameRates && (hasNoFrameRatesYet || frameRateChanged);
    if (shouldRecordNewFrameRate) {
        SENTRY_LOG_DEBUG(@"Recording new frame rate at %llu.", self.previousFrameSystemTimestamp);
        [self.frameRateTimestamps addObject:@{
            @"timestamp" : @(self.previousFrameSystemTimestamp),
            @"frame_rate" : @(currentFrameRate),
        }];
    }
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED

    CFTimeInterval frameDuration = thisFrameTimestamp - self.previousFrameTimestamp;

    if (frameDuration > slowFrameThreshold(currentFrameRate)
        && frameDuration <= SentryFrozenFrameThreshold) {
        atomic_fetch_add_explicit(&_slowFrames, 1, SentryFramesMemoryOrder);
#    if SENTRY_TARGET_PROFILING_SUPPORTED
        SENTRY_LOG_DEBUG(@"Capturing slow frame starting at %llu and ending at %llu.",
            self.previousFrameSystemTimestamp, thisFrameSystemTimestamp);
        [self recordTimestampStart:@(self.previousFrameSystemTimestamp)
                               end:@(thisFrameSystemTimestamp)
                             array:self.slowFrameTimestamps];
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED
    } else if (frameDuration > SentryFrozenFrameThreshold) {
        atomic_fetch_add_explicit(&_frozenFrames, 1, SentryFramesMemoryOrder);
#    if SENTRY_TARGET_PROFILING_SUPPORTED
        SENTRY_LOG_DEBUG(@"Capturing frozen frame starting at %llu and ending at %llu.",
            self.previousFrameSystemTimestamp, thisFrameSystemTimestamp);
        [self recordTimestampStart:@(self.previousFrameSystemTimestamp)
                               end:@(thisFrameSystemTimestamp)
                             array:self.frozenFrameTimestamps];
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED
    } else {
        SENTRY_LOG_DEBUG(@"Rendered normal frame starting at %llu and ending at %llu.",
            self.previousFrameSystemTimestamp, thisFrameSystemTimestamp);
    }

    atomic_fetch_add_explicit(&_totalFrames, 1, SentryFramesMemoryOrder);
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
- (void)recordTimestampStart:(NSNumber *)start end:(NSNumber *)end array:(NSMutableArray *)array
{
    BOOL shouldRecord = [SentryProfiler isRunning];
#        if defined(TEST) || defined(TESTCI)
    shouldRecord = YES;
#        endif
    if (shouldRecord) {
        [array addObject:@{ @"start_timestamp" : start, @"end_timestamp" : end }];
    }
}
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED

- (SentryScreenFrames *)currentFrames
{
    NSUInteger total = atomic_load_explicit(&_totalFrames, SentryFramesMemoryOrder);
    NSUInteger slow = atomic_load_explicit(&_slowFrames, SentryFramesMemoryOrder);
    NSUInteger frozen = atomic_load_explicit(&_frozenFrames, SentryFramesMemoryOrder);

#    if SENTRY_TARGET_PROFILING_SUPPORTED
    return [[SentryScreenFrames alloc] initWithTotal:total
                                              frozen:frozen
                                                slow:slow
                                 slowFrameTimestamps:self.slowFrameTimestamps
                               frozenFrameTimestamps:self.frozenFrameTimestamps
                                 frameRateTimestamps:self.frameRateTimestamps];
#    else
    return [[SentryScreenFrames alloc] initWithTotal:total frozen:frozen slow:slow];
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED
}

- (void)stop
{
    _isRunning = NO;
    [self.displayLinkWrapper invalidate];
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

@end

#endif
