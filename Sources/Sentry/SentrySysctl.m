#import "SentrySysctl.h"
#import "SentryCrashSysCtl.h"
#include <stdio.h>
#include <time.h>

static uint64_t mod_init_time_in_millis;

static inline uint64_t
sentry__msec_time(void)
{
    struct timeval tv;
    return (gettimeofday(&tv, NULL) == 0) ? (uint64_t)tv.tv_sec * 1000 + tv.tv_usec / 1000 : 0;
}

void
sentry_mod_init_hook(int argc, char **argv, char **envp)
{
    mod_init_time_in_millis = sentry__msec_time();
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
    return [NSDate dateWithTimeIntervalSince1970:mod_init_time_in_millis / 1000];
}

@end
