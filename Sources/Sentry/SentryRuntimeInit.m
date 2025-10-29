#import "SentryRuntimeInit.h"
#import "SentryCrashSysCtl.h"
#import "SentrySwift.h"
#import "SentryTime.h"

static NSDate *moduleInitializationTimestamp;
static uint64_t runtimeInitSystemTimestamp;
static NSDate *runtimeInit = nil;

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

@implementation SentryRuntimeInit

+ (void)load
{
    runtimeInit = [NSDate date];

    // this will be used for launch profiles. those are started from SentryTracer.load, and while
    // there's no guarantee on whether that or this load method will be called first, the difference
    // in time has been observed to only be on the order of single milliseconds, not significant
    // enough to make a difference in outcomes
    runtimeInitSystemTimestamp = [SentryDefaultCurrentDateProvider getAbsoluteTime];
}

- (uint64_t)runtimeInitSystemTimestamp
{
    return runtimeInitSystemTimestamp;
}

- (NSDate *)runtimeInitTimestamp
{
    return runtimeInit;
}

- (NSDate *)moduleInitializationTimestamp
{
    return moduleInitializationTimestamp;
}

@end
