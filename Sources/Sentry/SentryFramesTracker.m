#import "SentryFramesTracker.h"
#import "SentryDisplayLinkWrapper.h"
#import "SentryNSArrayRingBuffer.h"
#import "SentryProfilingConditionals.h"
#import "SentryTracer.h"
#import <SentryLog.h>
#import <SentryScreenFrames.h>
#include <stdatomic.h>

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>

/**
 * A ring-buffered version of @c SentryFrameTimestampInfo so we can build the results here and limit
 * how many timestamps we will retain.
 */
typedef SentryNSArrayRingBuffer<NSDictionary<NSString *, NSNumber *> *>
    SentryMutableFrameTimestampInfo;

static CFTimeInterval const SentryFrozenFrameThreshold = 0.7;
static CFTimeInterval const SentryPreviousFrameInitialValue = -1;
static NSUInteger const SentryNumberOfFrameTimestampsToRetain = 10000;

/**
 * Relaxed memoring ordering is typical for incrementing counters. This operation only requires
 * atomicity but not ordering or synchronization.
 */
static memory_order const SentryFramesMemoryOrder = memory_order_relaxed;

@interface
SentryFramesTracker ()

@property (nonatomic, strong, readonly) SentryDisplayLinkWrapper *displayLinkWrapper;
@property (nonatomic, assign) CFTimeInterval previousFrameTimestamp;
#    if SENTRY_TARGET_PROFILING_SUPPORTED
@property (nonatomic, readwrite) SentryMutableFrameTimestampInfo *frameTimestamps;
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED

@end

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
    self.frameTimestamps = [[SentryMutableFrameTimestampInfo alloc]
        initWithCapacity:SentryNumberOfFrameTimestampsToRetain];
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED
}

- (void)start
{
    _isRunning = YES;
    [_displayLinkWrapper linkWithTarget:self selector:@selector(displayLinkCallback)];
}

- (void)displayLinkCallback
{
    CFTimeInterval lastFrameTimestamp = self.displayLinkWrapper.timestamp;

    if (self.previousFrameTimestamp == SentryPreviousFrameInitialValue) {
        self.previousFrameTimestamp = lastFrameTimestamp;
        return;
    }

    // Calculate the actual frame rate as pointed out by the Apple docs:
    // https://developer.apple.com/documentation/quartzcore/cadisplaylink?language=objc The actual
    // frame rate can change at any time by setting preferredFramesPerSecond or due to ProMotion
    // display, low power mode, critical thermal state, and accessibility settings. Therefore we
    // need to check the frame rate for every callback.
    // targetTimestamp is only available on iOS 10.0 and tvOS 10.0 and above. We use a fallback of
    // 60 fps.
    double actualFramesPerSecond = 60.0;
    if (@available(iOS 10.0, tvOS 10.0, *)) {
        actualFramesPerSecond
            = 1 / (self.displayLinkWrapper.targetTimestamp - self.displayLinkWrapper.timestamp);
    }

    CFTimeInterval frameDuration = lastFrameTimestamp - self.previousFrameTimestamp;

    if (frameDuration > slowFrameThreshold && frameDuration <= SentryFrozenFrameThreshold) {
        atomic_fetch_add_explicit(&_slowFrames, 1, SentryFramesMemoryOrder);
#    if SENTRY_TARGET_PROFILING_SUPPORTED
        [self recordTimestampStart:@(self.previousFrameTimestamp) end:@(lastFrameTimestamp)];
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED
    } else if (frameDuration > SentryFrozenFrameThreshold) {
        atomic_fetch_add_explicit(&_frozenFrames, 1, SentryFramesMemoryOrder);
#    if SENTRY_TARGET_PROFILING_SUPPORTED
        [self recordTimestampStart:@(self.previousFrameTimestamp) end:@(lastFrameTimestamp)];
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED
    }

    atomic_fetch_add_explicit(&_totalFrames, 1, SentryFramesMemoryOrder);

    self.previousFrameTimestamp = lastFrameTimestamp;
}

#    if SENTRY_TARGET_PROFILING_SUPPORTED
- (void)recordTimestampStart:(NSNumber *)start end:(NSNumber *)end
{
    if (self.currentTracer.isProfiling) {
        [self.frameTimestamps addObject:@{ @"start_timestamp" : start, @"end_timestamp" : end }];
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
                                          timestamps:self.frameTimestamps.array];
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED
}

- (void)stop
{
    _isRunning = NO;
    [self.displayLinkWrapper invalidate];
}

@end

#endif
