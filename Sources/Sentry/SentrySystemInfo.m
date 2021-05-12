#import "SentrySystemInfo.h"
#import "SentryCrashSysCtl.h"
#import <Foundation/Foundation.h>

@implementation SentrySystemInfo

- (NSDate *)systemBootTimestamp
{
    struct timeval value = sentrycrashsysctl_timeval(CTL_KERN, KERN_BOOTTIME);
    return [NSDate dateWithTimeIntervalSince1970:value.tv_sec + value.tv_usec / 1E6];
}

@end
