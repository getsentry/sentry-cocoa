#import "SentryFramesTracker.h"
#import "SentryDisplayLinkWrapper.h"
#import "SentryLog.h"
#import "SentryOptions.h"
#include <stdatomic.h>

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>
#endif

static CFTimeInterval const SentryFrozenFrameThreshold = 0.7;

/**
 * Relaxed memoring ordering is typical for incrementing counters. This operation only requires
 * atomicity but not ordering or synchronization.
 */
static memory_order SentryFramesMemoryOrder = memory_order_relaxed;

@interface
SentryFramesTracker ()

@property (nonatomic, strong, readonly) SentryOptions *options;
@property (nonatomic, assign, readonly) CFTimeInterval slowFrameThreshold;
@property (nonatomic, strong, readonly) SentryDisplayLinkWrapper *displayLinkWrapper;

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

- (instancetype)initWithOptions:(SentryOptions *)options
             displayLinkWrapper:(SentryDisplayLinkWrapper *)displayLinkWrapper
{
    if (self = [super init]) {
        _options = options;
        _displayLinkWrapper = displayLinkWrapper;
        // Most frames take just a few microseconds longer than the optimal caculated duration.
        // Therefore we substract one, because otherwise almost all frames would be slow.
        _slowFrameThreshold = 1 / ((double)[UIScreen.mainScreen maximumFramesPerSecond] - 1);

        atomic_store_explicit(&_totalFrames, 0, SentryFramesMemoryOrder);
        atomic_store_explicit(&_frozenFrames, 0, SentryFramesMemoryOrder);
        atomic_store_explicit(&_slowFrames, 0, SentryFramesMemoryOrder);
    }
    return self;
}

- (void)start
{
    [_displayLinkWrapper linkWithTarget:self selector:@selector(displayLinkCallback)];
}

- (void)displayLinkCallback
{
    static CFTimeInterval previousFrameTimestamp = -1;
    CFTimeInterval lastFrameTimestamp = self.displayLinkWrapper.timestamp;
    CFTimeInterval frameDuration = lastFrameTimestamp - previousFrameTimestamp;

    if (frameDuration > self.slowFrameThreshold && frameDuration < SentryFrozenFrameThreshold) {
        atomic_fetch_add_explicit(&_slowFrames, 1, SentryFramesMemoryOrder);
    }

    if (frameDuration > SentryFrozenFrameThreshold) {
        atomic_fetch_add_explicit(&_frozenFrames, 1, SentryFramesMemoryOrder);
    }

    atomic_fetch_add_explicit(&_totalFrames, 1, SentryFramesMemoryOrder);

    previousFrameTimestamp = lastFrameTimestamp;
}

- (NSUInteger)currentTotalFrames
{
    return atomic_load_explicit(&_totalFrames, SentryFramesMemoryOrder);
}

- (NSUInteger)currentSlowFrames
{
    return atomic_load_explicit(&_slowFrames, SentryFramesMemoryOrder);
}

- (NSUInteger)currentFrozenFrames
{
    return atomic_load_explicit(&_frozenFrames, SentryFramesMemoryOrder);
}

- (void)stop
{
    [self.displayLinkWrapper invalidate];
}

@end
