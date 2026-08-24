#import "AppDelegate.h"
@import CoreData;
@import SentryObjC;

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    NSArray<NSString *> *args = NSProcessInfo.processInfo.arguments;
    NSDictionary<NSString *, NSString *> *env = NSProcessInfo.processInfo.environment;

    [SentryObjCSDK startWithConfigureOptions:^(SentryObjCOptions *options) {
        options.dsn = @"https://6cc9bae94def43cab8444a99e0031c28@o447951.ingest.sentry.io/5428557";
        options.debug = YES;
        options.attachScreenshot = YES;
        options.attachViewHierarchy = YES;

        if (env[@"--io.sentry.tracesSamplerValue"] != nil) {
            options.tracesSampler
                = ^NSNumber *_Nullable(SentryObjCSamplingContext *_Nonnull samplingContext)
            {
                return @([env[@"--io.sentry.tracesSamplerValue"] doubleValue]);
            };
        }

        options.tracesSampleRate = @1.0;
        if (env[@"--io.sentry.tracesSampleRate"] != nil) {
            options.tracesSampleRate = @([env[@"--io.sentry.tracesSampleRate"] doubleValue]);
        }

        SentryObjCHttpStatusCodeRange *httpStatusCodeRange =
            [[SentryObjCHttpStatusCodeRange alloc] initWithMin:400 max:599];
        options.failedRequestStatusCodes = @[ httpStatusCodeRange ];

        options.sessionReplay.sessionSampleRate = 0;
        options.sessionReplay.onErrorSampleRate = 1;
        options.sessionReplay.maskAllText = YES;
        options.sessionReplay.maskAllImages = YES;
        options.sessionReplay.enableViewRendererV2
            = ![args containsObject:@"--disable-view-renderer-v2"];
        options.sessionReplay.enableFastViewRendering
            = ![args containsObject:@"--disable-fast-view-rendering"];

        options.enableFileManagerSwizzling
            = ![args containsObject:@"--disable-filemanager-swizzling"];

        options.initialScope = ^SentryObjCScope *(SentryObjCScope *scope) {
            [scope setTagValue:@"" forKey:@""];
            return scope;
        };

        if (@available(iOS 13.0, *)) {
            options.configureUserFeedback = ^(
                SentryObjCUserFeedbackConfiguration *_Nonnull config) {
                if ([args containsObject:@"--io.sentry.feedback.all-defaults"]) {
                    return;
                }
                config.useShakeGesture = YES;
                config.showFormForScreenshots = YES;
                config.configureForm = ^(SentryObjCUserFeedbackFormConfiguration *_Nonnull uiForm) {
                    uiForm.formTitle = @"Jank Report";
                    uiForm.submitButtonLabel = @"Report that jank";
                    uiForm.messagePlaceholder
                        = @"Describe the nature of the jank. Its essence, if you will.";
                    uiForm.useSentryUser = YES;
                };
                config.configureTheme
                    = ^(SentryObjCUserFeedbackThemeConfiguration *_Nonnull theme) {
                          theme.fontFamily = @"ChalkboardSE-Regular";
                      };
                config.onSubmitSuccess = ^(NSDictionary<NSString *, id> *_Nonnull info) {
                    NSLog(@"Feedback submitted successfully: %@", info);
                };
                config.onSubmitError = ^(
                    NSError *_Nonnull error) { NSLog(@"Failed to submit feedback: %@", error); };
            };
        }
    }];

    return YES;
}

#pragma mark - UISceneSession lifecycle

- (UISceneConfiguration *)application:(UIApplication *)application
    configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession
                                   options:(UISceneConnectionOptions *)options
{
    return [[UISceneConfiguration alloc] initWithName:@"Default Configuration"
                                          sessionRole:connectingSceneSession.role];
}

@end
