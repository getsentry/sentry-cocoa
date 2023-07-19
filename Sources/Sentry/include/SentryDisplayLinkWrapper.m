#import "SentryDisplayLinkWrapper.h"

#if SENTRY_HAS_UIKIT

#    import <QuartzCore/QuartzCore.h>

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

- (void)linkWithTarget:(id)target selector:(SEL)sel
{
    // ???: Need to weak link QuartzCore/CADisplayLink?
    displayLink = [CADisplayLink displayLinkWithTarget:target selector:sel];
    [displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)invalidate
{
    [displayLink invalidate];
}

@end

#endif // SENTRY_HAS_UIKIT
