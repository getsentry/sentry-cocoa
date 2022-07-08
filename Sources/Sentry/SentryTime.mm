#import "SentryTime.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import <Foundation/Foundation.h>
#    import <ctime>
#    import <mach/mach_time.h>

#    import "SentryMachLogging.hpp"

uint64_t
getAbsoluteTime()
{
    if (@available(macOS 10.12, iOS 10.0, *)) {
        return clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
    }
    return mach_absolute_time();
}

uint64_t
getDurationNs(uint64_t startTimestamp, uint64_t endTimestamp)
{
    assert(endTimestamp >= startTimestamp);
    uint64_t duration = endTimestamp - startTimestamp;
    if (@available(macOS 10.12, iOS 10.0, *)) {
        return duration;
    }

    static struct mach_timebase_info info;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ SENTRY_PROF_LOG_KERN_RETURN(mach_timebase_info(&info)); });
    duration *= info.numer;
    duration /= info.denom;
    return duration;
}

#endif
