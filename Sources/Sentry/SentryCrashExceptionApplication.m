#import <Foundation/Foundation.h>

#if TARGET_OS_OSX && !SENTRY_NO_UI_FRAMEWORK

#    import "SentryCrashExceptionApplication.h"
#    import "SentryCrashExceptionApplicationHelper.h"
#    import "SentryUncaughtNSExceptions.h"
#    import <AppKit/NSApplication.h>

// Private AppKit method called on the application instance during CATransaction flush.
@interface NSApplication (SentryCrashOnException)
- (void)_crashOnException:(NSException *)exception;
@end

@implementation SentryCrashExceptionApplication

- (void)reportException:(NSException *)exception
{
    [SentryUncaughtNSExceptions configureCrashOnExceptions];
    // We cannot test an NSApplication because you create more than one at a time, so we use a
    // helper to hold the logic.
    [SentryCrashExceptionApplicationHelper reportException:exception];
    [super reportException:exception];
}

- (void)_crashOnException:(NSException *)exception
{
    // AppKit calls -[NSApp _crashOnException:] on the application instance in some code paths
    // (e.g., CATransaction flush). We capture the exception via the crash reporter's uncaught
    // exception handler, which synchronously writes the crash report with the exception's original
    // call stack before the process terminates.
    [SentryCrashExceptionApplicationHelper reportException:exception];
    [super _crashOnException:exception];
}

@end

#endif // TARGET_OS_OSX
