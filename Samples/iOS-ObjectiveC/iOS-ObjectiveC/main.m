#import "AppDelegate.h"
#import <UIKit/UIKit.h>

@import Sentry;

int
main(int argc, char *argv[])
{
    NSString *appDelegateClassName;
    @autoreleasepool {
        // Setup code that might create autoreleased objects goes here.
        appDelegateClassName = NSStringFromClass([AppDelegate class]);
    }
    [SentrySDK installHooks];
    return UIApplicationMain(argc, argv, nil, appDelegateClassName);
}
