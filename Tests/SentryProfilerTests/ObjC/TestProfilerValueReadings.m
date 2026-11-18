#import "TestProfilerValueReadings.h"

#if SENTRY_PROFILER_TESTS_SUPPORTED
@implementation TestProfilerValueReadings
- (SentryProfilingSystemMetrics *)systemMetrics
{
    return [[SentryProfilingSystemMetrics alloc] initWithCPUUsage:self.failReadings ? nil : @25
                                             memoryFootprintBytes:self.failReadings ? nil : @1000
                                                   cpuEnergyUsage:self.failReadings ? nil : @500];
}
@end
#endif
