#import "TestProfilerValueBackend.h"
#if SENTRY_PROFILER_TESTS_SUPPORTED
@implementation TestProfilerValueBackend
- (NSTimer *_Nullable)scheduledTimerWithInterval:(NSTimeInterval)interval
                                         repeats:(BOOL)repeats
                                           block:(dispatch_block_t)block
{
    self.lastTimer = [super scheduledTimerWithInterval:interval repeats:repeats block:block];
    return self.lastTimer;
}
#    if SENTRY_HAS_UIKIT
- (SentryScreenFrames *_Nullable)copyCurrentFrames
{
    return self.frames;
}
#    endif
- (id<SentryCurrentDateProvider>)dateProvider
{
    return self.clock;
}
- (SentryProfilingSystemMetrics *)systemMetrics
{
    return [self.metrics systemMetrics];
}
@end
#endif
