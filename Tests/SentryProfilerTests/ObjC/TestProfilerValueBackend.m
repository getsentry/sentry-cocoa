#import "TestProfilerValueBackend.h"
#if SENTRY_PROFILER_TESTS_SUPPORTED
@implementation TestProfilerValueBackend
- (SentryProfilingSystemMetrics *)systemMetrics
{
    return [self.metrics systemMetrics];
}
@end
#endif
