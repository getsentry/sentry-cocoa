#import "OS27PrewarmProbeEarly.h"

#import <mach/mach_time.h>
#import <sys/sysctl.h>
#import <sys/types.h>
#import <unistd.h>

#include <stdlib.h>
#include <string.h>

static CFAbsoluteTime earlyConstructorTimestamp;
static CFAbsoluteTime loadTimestamp;
static CFAbsoluteTime lateConstructorTimestamp;
static uint64_t earlyConstructorContinuousTime;
static uint64_t loadContinuousTime;
static uint64_t lateConstructorContinuousTime;
static BOOL activePrewarmAtEarlyConstructor;
static BOOL activePrewarmAtLoad;
static BOOL activePrewarmAtLateConstructor;

static BOOL
isActivePrewarm(void)
{
    const char *value = getenv("ActivePrewarm");
    return value != NULL && strcmp(value, "1") == 0;
}

__attribute__((constructor(101))) static void
os27PrewarmEarlyConstructor(void)
{
    earlyConstructorTimestamp = CFAbsoluteTimeGetCurrent();
    earlyConstructorContinuousTime = mach_continuous_time();
    activePrewarmAtEarlyConstructor = isActivePrewarm();
}

__attribute__((constructor(65535))) static void
os27PrewarmLateConstructor(void)
{
    lateConstructorTimestamp = CFAbsoluteTimeGetCurrent();
    lateConstructorContinuousTime = mach_continuous_time();
    activePrewarmAtLateConstructor = isActivePrewarm();
}

static NSDate *_Nullable processStartTimestamp(BOOL *isDebuggerAttached)
{
    struct kinfo_proc processInfo;
    memset(&processInfo, 0, sizeof(processInfo));

    size_t processInfoSize = sizeof(processInfo);
    int mib[] = { CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid() };
    if (sysctl(mib, 4, &processInfo, &processInfoSize, NULL, 0) != 0) {
        return nil;
    }

    if (isDebuggerAttached != NULL) {
        *isDebuggerAttached = (processInfo.kp_proc.p_flag & P_TRACED) != 0;
    }

    struct timeval startTime = processInfo.kp_proc.p_starttime;
    NSTimeInterval timestamp = startTime.tv_sec + startTime.tv_usec / 1E6;
    return [NSDate dateWithTimeIntervalSince1970:timestamp];
}

@implementation OS27PrewarmProbeEarly

+ (void)load
{
    loadTimestamp = CFAbsoluteTimeGetCurrent();
    loadContinuousTime = mach_continuous_time();
    activePrewarmAtLoad = isActivePrewarm();
}

+ (NSDictionary<NSString *, id> *)snapshot
{
    BOOL debuggerAttached = NO;
    NSDate *processStart = processStartTimestamp(&debuggerAttached);
    NSMutableDictionary<NSString *, id> *snapshot = [@{
        @"activePrewarmAtEarlyConstructor" : @(activePrewarmAtEarlyConstructor),
        @"activePrewarmAtLoad" : @(activePrewarmAtLoad),
        @"activePrewarmAtLateConstructor" : @(activePrewarmAtLateConstructor),
        @"activePrewarmAtSnapshot" : @(isActivePrewarm()),
        @"debuggerAttached" : @(debuggerAttached),
        @"earlyConstructorContinuousTime" : @(earlyConstructorContinuousTime),
        @"earlyConstructorTimestamp" :
            [NSDate dateWithTimeIntervalSinceReferenceDate:earlyConstructorTimestamp],
        @"lateConstructorContinuousTime" : @(lateConstructorContinuousTime),
        @"lateConstructorTimestamp" :
            [NSDate dateWithTimeIntervalSinceReferenceDate:lateConstructorTimestamp],
        @"loadContinuousTime" : @(loadContinuousTime),
        @"loadTimestamp" : [NSDate dateWithTimeIntervalSinceReferenceDate:loadTimestamp],
        @"processIdentifier" : @(getpid()),
    } mutableCopy];

    if (processStart != nil) {
        snapshot[@"processStartTimestamp"] = processStart;
    }

    return snapshot;
}

@end
