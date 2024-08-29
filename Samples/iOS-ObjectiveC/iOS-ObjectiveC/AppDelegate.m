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
    NSArray<NSString *> *args = NSProcessInfo.processInfo.arguments;

    [SentrySDK startWithConfigureOptions:^(SentryOptions *options) {
        options.dsn = @"https://6cc9bae94def43cab8444a99e0031c28@o447951.ingest.sentry.io/5428557";
        options.debug = YES;
        options.tracesSampleRate = @1.0;
        options.attachScreenshot = YES;
        options.attachViewHierarchy = YES;
        if ([args containsObject:@"--io.sentry.profiling.enable"]) {
            options.profilesSampleRate = @1;
        }
        SentryHttpStatusCodeRange *httpStatusCodeRange =
            [[SentryHttpStatusCodeRange alloc] initWithMin:400 max:599];
        options.failedRequestStatusCodes = @[ httpStatusCodeRange ];

        options.experimental.sessionReplay.quality = SentryReplayQualityMedium;
        options.experimental.sessionReplay.redactAllText = true;
        options.experimental.sessionReplay.redactAllImages = true;
        options.experimental.sessionReplay.sessionSampleRate = 0;
        options.experimental.sessionReplay.onErrorSampleRate = 1;

        options.initialScope = ^(SentryScope *scope) {
            [scope setTagValue:@"" forKey:@""];
            return scope;
        };

        options.configureUserFeedback = ^(SentryUserFeedbackConfiguration *_Nonnull config) {
            config.useShakeGesture = YES;
            config.showFormForScreenshots = YES;
            config.configureWidget = ^(SentryUserFeedbackWidgetConfiguration *_Nonnull widget) {
                if ([args
                        containsObject:@"--io.sentry.iOS-Swift.auto-inject-user-feedback-widget"]) {
                    widget.triggerLabel = @"Report Jank";
                    widget.triggerAccessibilityLabel = @"io.sentry.iOS-Swift.button.report-jank";
                } else {
                    widget.autoInject = NO;
                }
            };
            config.configureForm = ^(SentryUserFeedbackFormConfiguration *_Nonnull uiForm) {
                uiForm.formTitle = @"Jank Report";
                uiForm.submitButtonLabel = @"Report that jank";
                uiForm.addScreenshotButtonLabel = @"Show us the jank";
                uiForm.messagePlaceholder
                    = @"Describe the nature of the jank. Its essence, if you will.";
                uiForm.lightThemeOverrides
                    = ^(SentryUserFeedbackThemeConfiguration *_Nonnull lightTheme) {
                          lightTheme.font = [UIFont fontWithName:@"Comic Sans" size:25];
                      };
            };
            config.onSubmitSuccess = ^(NSDictionary<NSString *, id> *_Nonnull info) {
                NSString *name = info[@"name"] ?: @"$shakespearean_insult_name";
                UIAlertController *alert = [UIAlertController
                    alertControllerWithTitle:@"Thanks?"
                                     message:[NSString stringWithFormat:
                                                           @"We have enough jank of our own, we "
                                                           @"really didn't need yours too, %@",
                                                       name]
                              preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"Derp"
                                                          style:UIAlertActionStyleDefault
                                                        handler:nil]];
                [self.window.rootViewController presentViewController:alert
                                                             animated:YES
                                                           completion:nil];
            };
            config.onSubmitError = ^(NSError *_Nonnull error) {
                UIAlertController *alert = [UIAlertController
                    alertControllerWithTitle:@"D'oh"
                                     message:[NSString
                                                 stringWithFormat:
                                                     @"You tried to report jank, and encountered "
                                                     @"more jank. The jank has you now: %@",
                                                 error]
                              preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"Derp"
                                                          style:UIAlertActionStyleDefault
                                                        handler:nil]];
                [self.window.rootViewController presentViewController:alert
                                                             animated:YES
                                                           completion:nil];
            };
        };
    }];

    return YES;
}

#pragma mark - UISceneSession lifecycle

@end
