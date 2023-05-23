#import "SentrySwiftAsyncIntegration.h"
#import "SentryCrashStackCursor_SelfThread.h"

@implementation SentrySwiftAsyncIntegration

- (BOOL)installWithOptions:(nonnull SentryOptions *)options
{
    sentrycrashsc_setSwiftAsyncStitching(options.stitchSwiftAsync);
    return options.stitchSwiftAsync;
}

- (void)uninstall {
    sentrycrashsc_setSwiftAsyncStitching(NO);
}

@end
