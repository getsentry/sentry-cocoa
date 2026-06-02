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
    [SentryObjCSDK startWithConfigureOptions:^(SentryObjCOptions *options) {
        options.dsn = @"https://6cc9bae94def43cab8444a99e0031c28@o447951.ingest.sentry.io/5428557";
        options.debug = YES;
        options.tracesSampleRate = @1.0;

        options.sessionReplay.sessionSampleRate = 0;
        options.sessionReplay.onErrorSampleRate = 1;
    }];

    SentryObjCLogger *logger = [SentryObjCSDK logger];

    // Plain string log
    [logger debug:@"App launched"];

    // Format string — values captured as structured template attributes
    NSString *username = @"John";
    NSInteger itemCount = 42;
    [logger infoWithFormat:@"User %@ processed %ld items", username, (long)itemCount];

    // Format string with extra attributes
    [logger debugWithAttributes:@{ @"source" : @"appLaunch" }
                         format:@"Startup completed in %.2f seconds", 1.234];

    return YES;
}

@end
