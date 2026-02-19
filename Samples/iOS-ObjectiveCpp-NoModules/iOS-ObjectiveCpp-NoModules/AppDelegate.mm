// Demonstrates the issue from #4543 / #6342: Using Sentry from Objective-C++
// with CLANG_ENABLE_MODULES=NO. We must use #import instead of @import.
//
// With modules disabled, #import <Sentry/Sentry.h> does NOT expose Swift APIs
// (SentrySDK, SentryOptions, options.sessionReplay). We intentionally do NOT
// include Sentry-Swift.h here because that fails with forward declaration
// errors (UIView, UIWindowLevel, etc.) when included from .mm files without
// modules. So we only have #import <Sentry/Sentry.h> and the build fails with
// "use of undeclared identifier 'SentrySDK'" - reproducing the issue.
//
// The sample will NOT build until the pure ObjC SDK wrapper (#6342) is implemented.

#import "AppDelegate.h"
#import <Sentry/Sentry.h>
#import <UIKit/UIKit.h>

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Fails: SentrySDK undeclared - #import <Sentry/Sentry.h> does not expose
    // Swift APIs when CLANG_ENABLE_MODULES=NO (SDK 8.54+).
    [SentrySDK startWithConfigureOptions:^(SentryOptions *options) {
        options.dsn = @"https://6cc9bae94def43cab8444a99e0031c28@o447951.ingest.sentry.io/5428557";
        options.debug = YES;
        options.tracesSampleRate = @1.0;

        // This fails: options.sessionReplay not exposed without @import
        options.sessionReplay.sessionSampleRate = 0;
        options.sessionReplay.onErrorSampleRate = 1;
    }];

    return YES;
}

@end
