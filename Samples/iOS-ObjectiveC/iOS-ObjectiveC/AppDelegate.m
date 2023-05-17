#import "AppDelegate.h"
@import CoreData;
@import Sentry;

@interface
AppDelegate ()

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.

    [SentrySDK startWithConfigureOptions:^(SentryOptions *options) {
        options.dsn = @"https://6cc9bae94def43cab8444a99e0031c28@o447951.ingest.sentry.io/5428557";
        options.debug = YES;
        options.tracesSampleRate = @1.0;
        options.attachScreenshot = YES;
        options.attachViewHierarchy = YES;
        if ([NSProcessInfo.processInfo.arguments containsObject:@"--io.sentry.profiling.enable"]) {
            options.profilesSampleRate = @1;
        }
        SentryHttpStatusCodeRange *httpStatusCodeRange =
            [[SentryHttpStatusCodeRange alloc] initWithMin:400 max:599];
        options.failedRequestStatusCodes = @[ httpStatusCodeRange ];

        options.initialScope = ^(SentryScope *scope) {
            [scope setTagValue:@"" forKey:@""];
            return scope;
        };
    }];

    return YES;
}

#pragma mark - UISceneSession lifecycle

@end
