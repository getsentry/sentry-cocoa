#import "SentrySysctlObjC.h"
#import "SentryLogC.h"
#import "SentrySwift.h"
#import "SentryTime.h"
#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <sys/sysctl.h>
#include <time.h>
#include <unistd.h>

static NSDate *moduleInitializationTimestamp;
static uint64_t runtimeInitSystemTimestamp;
static NSDate *runtimeInit = nil;

static NSTimeInterval
sentryTimeInterval(struct timeval value)
{
    return value.tv_sec + value.tv_usec / 1E6;
}

static NSTimeInterval
sentrySystemBootTimestamp(void)
{
    int mib[] = { CTL_KERN, KERN_BOOTTIME };
    struct timeval value = { 0 };
    size_t size = sizeof(value);

    if (sysctl(mib, sizeof(mib) / sizeof(*mib), &value, &size, NULL, 0) != 0) {
        SENTRY_LOG_ERROR(@"Could not get system boot time: %s", strerror(errno));
        return 0;
    }

    return sentryTimeInterval(value);
}

static NSTimeInterval
sentryCurrentProcessStartTimestamp(void)
{
    int mib[] = { CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid() };
    struct kinfo_proc processInfo = { 0 };
    size_t size = sizeof(processInfo);

    if (sysctl(mib, sizeof(mib) / sizeof(*mib), &processInfo, &size, NULL, 0) != 0) {
        SENTRY_LOG_ERROR(@"Could not get current process start time: %s", strerror(errno));
        return 0;
    }

    return sentryTimeInterval(processInfo.kp_proc.p_un.__p_starttime);
}

/**
 * Constructor priority must be bounded between 101 and 65535 inclusive, see
 * https://gcc.gnu.org/onlinedocs/gcc-4.7.0/gcc/Function-Attributes.html and
 * https://gcc.gnu.org/onlinedocs/gcc-4.7.0/gcc/C_002b_002b-Attributes.html#C_002b_002b-Attributes
 * The constructor attribute causes the function to be called automatically before execution enters
 * @c main() . The lower the priority number, the sooner the constructor runs, which means 100 runs
 * before 101. As we want to be as close to @c main() as possible, we choose a high number.
 *
 * Previously, we used @c __DATA,__mod_init_func , which leads to compilation errors and runtime
 * crashes when enabling the address sanitizer.
 */
__used __attribute__((constructor(60000))) static void
sentryModuleInitializationHook(void)
{
    moduleInitializationTimestamp = [NSDate date];
}

@interface SentrySysctlObjC ()
@property (nonatomic, copy) SentrySystemTimestampProvider systemBootTimestampProvider;
@property (nonatomic, copy) SentrySystemTimestampProvider processStartTimestampProvider;
@end

@implementation SentrySysctlObjC

+ (void)load
{
    runtimeInit = [NSDate date];

    // this will be used for launch profiles. those are started from SentryTracer.load, and while
    // there's no guarantee on whether that or this load method will be called first, the difference
    // in time has been observed to only be on the order of single milliseconds, not significant
    // enough to make a difference in outcomes
    runtimeInitSystemTimestamp = [SentryDefaultCurrentDateProvider getAbsoluteTime];
}

- (instancetype)init
{
    return [self
        initWithSystemBootTimestampProvider:^{ return sentrySystemBootTimestamp(); }
        processStartTimestampProvider:^{ return sentryCurrentProcessStartTimestamp(); }];
}

- (instancetype)
    initWithSystemBootTimestampProvider:(SentrySystemTimestampProvider)systemBootTimestampProvider
          processStartTimestampProvider:(SentrySystemTimestampProvider)processStartTimestampProvider
{
    if (self = [super init]) {
        _systemBootTimestampProvider = systemBootTimestampProvider;
        _processStartTimestampProvider = processStartTimestampProvider;
    }
    return self;
}

- (NSDate *)runtimeInitTimestamp
{
    return runtimeInit;
}

- (NSDate *)systemBootTimestamp
{
    return [NSDate dateWithTimeIntervalSince1970:self.systemBootTimestampProvider()];
}

- (NSDate *)processStartTimestamp
{
    return [NSDate dateWithTimeIntervalSince1970:self.processStartTimestampProvider()];
}

- (uint64_t)runtimeInitSystemTimestamp
{
    return runtimeInitSystemTimestamp;
}

- (NSDate *)moduleInitializationTimestamp
{
    return moduleInitializationTimestamp;
}

@end
