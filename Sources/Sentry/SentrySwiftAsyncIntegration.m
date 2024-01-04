#import "SentrySwiftAsyncIntegration.h"
#import "SentryCrashStackCursor_SelfThread.h"

@implementation SentrySwiftAsyncIntegration

+ (void)load
{
    NSLog(@"%llu %s", clock_gettime_nsec_np(CLOCK_UPTIME_RAW), __PRETTY_FUNCTION__);
}

- (BOOL)installWithOptions:(nonnull SentryOptions *)options
{
    sentrycrashsc_setSwiftAsyncStitching(options.swiftAsyncStacktraces);
    return options.swiftAsyncStacktraces;
}

- (void)uninstall
{
    sentrycrashsc_setSwiftAsyncStitching(NO);
}

@end
