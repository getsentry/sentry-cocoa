#import <Foundation/Foundation.h>

#if TARGET_OS_OSX && !SENTRY_NO_UI_FRAMEWORK

@import KSCrashRecording;

#    import "SentryNSExceptionCaptureHelper.h"

@implementation SentryNSExceptionCaptureHelper

static BOOL _insideReportException = NO;

+ (void)reportException:(NSException *)exception
{
    _insideReportException = YES;
    [self captureException:exception];
}

+ (void)reportExceptionDidFinish
{
    _insideReportException = NO;
}

+ (void)crashOnException:(NSException *)exception
{
    // When called from within reportException: (i.e., [super reportException:] internally
    // dispatches to _crashOnException: when NSApplicationCrashOnExceptions is YES),
    // the exception was already captured, so skip to avoid duplicate reports.
    if (!_insideReportException) {
        [self captureException:exception];
    }
}

+ (void)captureException:(NSException *)exception
{
    NSUncaughtExceptionHandler *handler = KSCrash.sharedInstance.uncaughtExceptionHandler;
    if (nil != handler && nil != exception) {
        handler(exception);
    }
}

@end

#endif // TARGET_OS_OSX
