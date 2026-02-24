#import <Foundation/Foundation.h>

#if TARGET_OS_OSX && !SENTRY_NO_UI_FRAMEWORK

#    import "SentryCrash.h"
#    import "SentryCrashExceptionApplication.h"
#    import "SentryCrashExceptionApplicationHelper.h"
#    import "SentrySwift.h"

@implementation SentryCrashExceptionApplicationHelper

+ (void)reportException:(NSException *)exception
{
    SentryCrashSwift *crash = SentryDependencyContainer.sharedInstance.crashReporter;
    if (nil != crash.uncaughtExceptionHandler && nil != exception) {
        crash.uncaughtExceptionHandler(exception);
    }
}

@end

#endif // TARGET_OS_OSX
