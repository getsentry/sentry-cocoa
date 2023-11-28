#import "SentryCurrentDateProvider.h"
#import "SentryTime.h"

@implementation SentryCurrentDateProvider

+ (void)load
{
    printf("%llu %s\n", clock_gettime_nsec_np(CLOCK_UPTIME_RAW), __PRETTY_FUNCTION__);
}

- (NSDate *_Nonnull)date
{
    return [NSDate date];
}

- (dispatch_time_t)dispatchTimeNow
{
    return dispatch_time(DISPATCH_TIME_NOW, 0);
}

- (NSInteger)timezoneOffset
{
    return [NSTimeZone localTimeZone].secondsFromGMT;
}

- (uint64_t)systemTime
{
    return getAbsoluteTime();
}

@end
