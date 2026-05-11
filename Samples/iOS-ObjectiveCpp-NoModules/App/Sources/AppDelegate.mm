// Uses Sentry from Objective-C++ with CLANG_ENABLE_MODULES=NO via the pure
// ObjC wrapper (SentryObjC). Import the umbrella header to access SentryObjCSDK,
// SentryOptions, sessionReplay, etc. without requiring Swift modules.

#import "AppDelegate.h"
#import <SentryObjC.h>
#import <UIKit/UIKit.h>

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [SentryObjCSDK startWithConfigureOptions:^(SentryOptions *options) {
        options.dsn = @"https://6cc9bae94def43cab8444a99e0031c28@o447951.ingest.sentry.io/5428557";
        options.debug = YES;
        options.tracesSampleRate = @1.0;

        options.sessionReplay.sessionSampleRate = 0;
        options.sessionReplay.onErrorSampleRate = 1;
    }];

    return YES;
}

@end
