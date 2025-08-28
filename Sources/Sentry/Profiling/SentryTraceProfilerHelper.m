#import "SentryTraceProfilerHelper.h"
#import "SentryDependencyContainer.h"
#import "SentrySwift.h"

@implementation SentryTraceProfilerHelper

+ (NSTimer *)timerWithTimeInterval:(NSTimeInterval)interval
                           repeats:(BOOL)repeats
                             block:(void (^)(NSTimer *timer))block
{
    return [SentryDependencyContainer.sharedInstance.timerFactory
        scheduledTimerWithTimeInterval:interval
                               repeats:repeats
                                 block:block];
}

@end
