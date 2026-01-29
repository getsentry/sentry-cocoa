#import "SentryAppStartTrackerHelper.h"

#if SENTRY_HAS_UIKIT

#    import "SentrySwift.h"

@implementation SentryAppStartTrackerHelper

+ (void)load
{
    // Invoked whenever this class is added to the Objective-C runtime.
    // Set values in SentryAppStartTracker
    SentryAppStartTracker.runtimeInitTimestamp = [NSDate date];

    // The OS sets this environment variable if the app start is pre warmed. There are no official
    // docs for this. Found at https://eisel.me/startup. Investigations show that this variable is
    // deleted after UIApplicationDidFinishLaunchingNotification, so we have to check it here.
    SentryAppStartTracker.isActivePrewarm =
        [[NSProcessInfo processInfo].environment[@"ActivePrewarm"] isEqualToString:@"1"];
}

@end

#endif // SENTRY_HAS_UIKIT
