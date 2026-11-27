#import <Foundation/Foundation.h>

#if TARGET_OS_OSX && !SENTRY_NO_UI_FRAMEWORK

#    import "SentryNSExceptionCaptureHelper.h"
#    import "SentrySwift.h"

@implementation SentryNSExceptionCaptureHelper

static BOOL _insideReportException = NO;
static NSUncaughtExceptionHandler *_uncaughtExceptionHandler = nil;
static __weak NSObject *_uncaughtExceptionHandlerOwner = nil;

+ (void)setUncaughtExceptionHandler:(NSUncaughtExceptionHandler *)uncaughtExceptionHandler
                              owner:(NSObject *)owner
{
    @synchronized(self) {
        _uncaughtExceptionHandler = uncaughtExceptionHandler;
        _uncaughtExceptionHandlerOwner = owner;
    }
}

+ (void)clearUncaughtExceptionHandlerForOwner:(NSObject *)owner
{
    @synchronized(self) {
        if (_uncaughtExceptionHandlerOwner == owner) {
            _uncaughtExceptionHandler = nil;
            _uncaughtExceptionHandlerOwner = nil;
        }
    }
}

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
    NSUncaughtExceptionHandler *uncaughtExceptionHandler = nil;
    @synchronized(self) {
        if (_uncaughtExceptionHandlerOwner != nil) {
            uncaughtExceptionHandler = _uncaughtExceptionHandler;
        }
    }
    if (uncaughtExceptionHandler != nil && exception != nil) {
        uncaughtExceptionHandler(exception);
    }
}

@end

#endif // TARGET_OS_OSX
