#import "SentryDisplayLinkWrapper.h"

#if UIKIT_LINKED

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

- (void)linkWithTarget:(id)target selector:(SEL)sel
{
    displayLink = [CADisplayLink displayLinkWithTarget:target selector:sel];
    [displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)invalidate
{
    [displayLink invalidate];
}

@end

#endif // UIKIT_LINKED
