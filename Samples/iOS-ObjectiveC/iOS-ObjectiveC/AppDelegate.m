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
        options.dsn = @"https://49962454dbc3404890bacf3133c30b09@crash.uu.163.com/2";
        options.debug = YES;
        options.sessionTrackingIntervalMillis = 5000UL;
        // Sampling 100% - In Production you probably want to adjust this
        options.tracesSampleRate = @1.0;
        options.enableFileIOTracking = YES;
        options.attachScreenshot = YES;
        options.attachViewHierarchy = YES;
        options.enableUserInteractionTracing = YES;
        options.environment = @"development";
        if ([NSProcessInfo.processInfo.arguments containsObject:@"--io.sentry.profiling.enable"]) {
            options.profilesSampleRate = @1;
        }
        options.enableCaptureFailedRequests = YES;
        SentryHttpStatusCodeRange *httpStatusCodeRange =
            [[SentryHttpStatusCodeRange alloc] initWithMin:400 max:599];
        options.failedRequestStatusCodes = @[ httpStatusCodeRange ];
    }];

    return YES;
}

#pragma mark - UISceneSession lifecycle

@end
