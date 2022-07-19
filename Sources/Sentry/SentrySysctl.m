#import "SentrySysctl.h"
#import "SentryCrashSysCtl.h"
#include <stdio.h>
#include <time.h>

static NSDate *moduleInitializationTimestamp;
static NSDate *runtimeInit = nil;

void
sentryModuleInitializationHook(int argc, char **argv, char **envp)
{
    moduleInitializationTimestamp = [NSDate date];
}
/**
 * Module initialization functions. The C++ compiler places static constructors here. For more info
 * visit:
 * https://github.com/aidansteele/osx-abi-macho-file-format-reference#table-2-the-sections-of-a__datasegment
 */
__attribute__((section("__DATA,__mod_init_func"))) typeof(sentryModuleInitializationHook) *__init
    = sentryModuleInitializationHook;

@implementation SentrySysctl

+ (void)load
{
    // Invoked whenever this class is added to the Objective-C runtime.
    runtimeInit = [NSDate date];
}

- (NSDate *)runtimeInitTimestamp
{
    return runtimeInit;
}

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

- (NSDate *)moduleInitializationTimestamp
{
    return moduleInitializationTimestamp;
}

@end
