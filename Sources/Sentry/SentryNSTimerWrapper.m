#import "SentryNSTimerWrapper.h"

@implementation SentryNSTimerWrapper

- (NSTimer *)scheduledTimerWithTimeInterval:(NSTimeInterval)interval
                                    repeats:(BOOL)repeats
                                      block:(void (^)(NSTimer *timer))block
{
    return [NSTimer scheduledTimerWithTimeInterval:interval repeats:repeats block:block];
}

#pragma mark - Testing

- (void)fire
{
    // no-op
}

@end
