#import <Foundation/Foundation.h>

#if TARGET_OS_OSX

#    import "SentryCrash.h"
#    import "SentryDependencyContainer.h"
#    import "SentrySwizzle.h"
#    import "SentryUncaughtNSExceptions.h"
#    import <AppKit/NSApplication.h>

@implementation SentryUncaughtNSExceptions

+ (void)capture:(NSException *)exception
{
    SentryCrash *crash = SentryDependencyContainer.sharedInstance.crashReporter;
    if (nil != crash.uncaughtExceptionHandler && nil != exception) {
        crash.uncaughtExceptionHandler(exception);
    }
}

@end

#endif // TARGET_OS_OSX
