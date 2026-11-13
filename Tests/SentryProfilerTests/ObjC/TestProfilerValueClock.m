#import "TestProfilerValueClock.h"
#if SENTRY_PROFILER_TESTS_SUPPORTED
@implementation TestProfilerValueClock
- (NSDate *)date
{
    return [NSDate dateWithTimeIntervalSince1970:123];
}
- (uint64_t)systemTime
{
    return 456;
}
- (NSInteger)timezoneOffset
{
    return 0;
}
- (NSTimeInterval)systemUptime
{
    return 0;
}
- (uint64_t)getAbsoluteTime
{
    return 456;
}
@end
#endif
