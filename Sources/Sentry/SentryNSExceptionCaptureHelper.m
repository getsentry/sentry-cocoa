#import <Foundation/Foundation.h>

#if TARGET_OS_OSX && !SENTRY_NO_UI_FRAMEWORK

#    import "SentryNSExceptionCaptureHelper.h"
#    import "SentrySwift.h"

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
#    if !SENTRY_DISABLE_SENTRYCRASH_V10
    SentryCrashSwift *crash = SentryDependencyContainer.sharedInstance.crashReporter;
    if (nil != crash.uncaughtExceptionHandler && nil != exception) {
        crash.uncaughtExceptionHandler(exception);
    }
#    else
    // KSCRASH_TODO(GH-8529): V10 does not forward AppKit exceptions to KSCrash, so this helper
    // is temporarily a no-op. Acceptance: SCV10-012 in SENTRYCRASH_V10_MIGRATION_LEDGER.md.
    (void)exception;
#    endif
}

@end

#endif // TARGET_OS_OSX
