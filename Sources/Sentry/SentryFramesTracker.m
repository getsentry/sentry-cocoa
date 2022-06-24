#import "SentryFramesTracker.h"
#import "SentryDisplayLinkWrapper.h"
#import <SentryLog.h>
#import <SentryScreenFrames.h>
#include <stdatomic.h>

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>

static CFTimeInterval const SentryFrozenFrameThreshold = 0.7;
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

    // Most frames take just a few microseconds longer than the optimal caculated duration.
    // Therefore we substract one, because otherwise almost all frames would be slow.
    CFTimeInterval slowFrameThreshold = 1 / (actualFramesPerSecond - 1);

    CFTimeInterval frameDuration = lastFrameTimestamp - self.previousFrameTimestamp;
    self.previousFrameTimestamp = lastFrameTimestamp;

    if (frameDuration > slowFrameThreshold && frameDuration <= SentryFrozenFrameThreshold) {
        atomic_fetch_add_explicit(&_slowFrames, 1, SentryFramesMemoryOrder);
    }

    if (frameDuration > SentryFrozenFrameThreshold) {
        atomic_fetch_add_explicit(&_frozenFrames, 1, SentryFramesMemoryOrder);
    }

    atomic_fetch_add_explicit(&_totalFrames, 1, SentryFramesMemoryOrder);
}

- (SentryScreenFrames *)currentFrames
{
    NSUInteger total = atomic_load_explicit(&_totalFrames, SentryFramesMemoryOrder);
    NSUInteger slow = atomic_load_explicit(&_slowFrames, SentryFramesMemoryOrder);
    NSUInteger frozen = atomic_load_explicit(&_frozenFrames, SentryFramesMemoryOrder);

    return [[SentryScreenFrames alloc] initWithTotal:total frozen:frozen slow:slow];
}

- (void)stop
{
    _isRunning = NO;
    [self.displayLinkWrapper invalidate];
}

@end

#endif
