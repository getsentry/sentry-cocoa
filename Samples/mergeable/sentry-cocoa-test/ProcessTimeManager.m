#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <sys/sysctl.h>

static CFTimeInterval
processStartTime()
{
    size_t len = 4;
    int mib[len];
    struct kinfo_proc kp;

    sysctlnametomib("kern.proc.pid", mib, &len);
    mib[3] = getpid();
    len = sizeof(kp);
    sysctl(mib, 4, &kp, &len, NULL, 0);

    struct timeval startTime = kp.kp_proc.p_un.__p_starttime;
    return startTime.tv_sec + startTime.tv_usec / 1e6;
}

static CFTimeInterval sPreMainStartTimeRelative;

CFTimeInterval
calculateStartTime()
{
    CFTimeInterval absoluteTimeToRelativeTime
        = CACurrentMediaTime() - [NSDate date].timeIntervalSince1970;
    sPreMainStartTimeRelative = processStartTime() + absoluteTimeToRelativeTime;
    return sPreMainStartTimeRelative;
}

CFTimeInterval
timeFromStartToNow()
{
    return CACurrentMediaTime() - sPreMainStartTimeRelative;
}
