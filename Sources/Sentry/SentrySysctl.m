#import "SentrySysctl.h"
#import "SentryCrashSysCtl.h"
#include <stdio.h>
#include <time.h>

static double mod_init_time_in_seconds;

void
sentry_mod_init_hook(int argc, char **argv, char **envp)
{
    struct timeval value;
    mod_init_time_in_seconds
        = (gettimeofday(&value, NULL) == 0) ? (uint64_t)value.tv_sec + value.tv_usec / 1E6 : 0;
}
__attribute__((section("__DATA,__mod_init_func"))) typeof(sentry_mod_init_hook) *__init
    = sentry_mod_init_hook;

@implementation SentrySysctl

- (NSDate *)systemBootTimestamp
{
    struct timeval value = sentrycrashsysctl_timeval(CTL_KERN, KERN_BOOTTIME);
    return [NSDate dateWithTimeIntervalSince1970:value.tv_sec + value.tv_usec / 1E6];
}

- (NSDate *)processStartTimestamp
{
    struct timeval startTime = sentrycrashsysctl_currentProcessStartTime();
    return [NSDate dateWithTimeIntervalSince1970:startTime.tv_sec + startTime.tv_usec / 1E6];
}

- (NSDate *)mainTimestamp
{
    return [NSDate dateWithTimeIntervalSince1970:mod_init_time_in_seconds];
}

@end
