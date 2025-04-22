#import "SentryDisplayLinkWrapper.h"

#if SENTRY_HAS_UIKIT

#    import <UIKit/UIKit.h>

@implementation SentryDisplayLinkWrapper {
    CADisplayLink *displayLink;
}

- (CFTimeInterval)timestamp
{
    return displayLink.timestamp;
}

- (CFTimeInterval)targetTimestamp API_AVAILABLE(ios(10.0), tvos(10.0))
{
    return displayLink.targetTimestamp;
}

- (void)linkWithTarget:(id)target
                    selector:(SEL)sel
    preferredFramesPerSecond:(NSInteger)preferredFramesPerSecond
{
    displayLink = [CADisplayLink displayLinkWithTarget:target selector:sel];
    if (preferredFramesPerSecond >= 0) {
        displayLink.preferredFramesPerSecond = preferredFramesPerSecond;
    }
    [displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)linkWithTarget:(id)target
                   selector:(SEL)sel
    preferredFrameRateRange:(CAFrameRateRange)preferredFrameRateRange API_AVAILABLE(ios(15.0))
{
    displayLink = [CADisplayLink displayLinkWithTarget:target selector:sel];
    displayLink.preferredFrameRateRange = preferredFrameRateRange;
    [displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)invalidate
{
    [displayLink invalidate];
    displayLink = nil;
}

- (BOOL)isRunning
{
    return displayLink != nil && !displayLink.isPaused;
}

@end

#endif // SENTRY_HAS_UIKIT
