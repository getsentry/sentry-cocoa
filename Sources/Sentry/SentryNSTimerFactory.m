#import "SentryNSTimerFactory.h"
#import "SentryInternalDefines.h"

@implementation SentryNSTimerFactory

- (NSTimer *)scheduledTimerWithTimeInterval:(NSTimeInterval)interval
                                    repeats:(BOOL)repeats
                                      block:(void (^)(NSTimer *timer))block
{
    SENTRY_ASSERT([NSThread isMainThread],
        @"Timers must be scheduled from the main thread, or they may never fire.");
    return [NSTimer scheduledTimerWithTimeInterval:interval repeats:repeats block:block];
}

- (NSTimer *)scheduledTimerWithTimeInterval:(NSTimeInterval)ti
                                     target:(id)aTarget
                                   selector:(SEL)aSelector
                                   userInfo:(nullable id)userInfo
                                    repeats:(BOOL)yesOrNo
{
    SENTRY_ASSERT([NSThread isMainThread],
        @"Timers must be scheduled from the main thread, or they may never fire.");
    return [NSTimer scheduledTimerWithTimeInterval:ti
                                            target:aTarget
                                          selector:aSelector
                                          userInfo:userInfo
                                           repeats:yesOrNo];
}

@end
