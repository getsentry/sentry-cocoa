#import "AppDelegate.h"
@import CoreData;
@import Sentry;
#import <Sentry/SentryOptions+Private.h>

#import "iOS_ObjectiveC-Swift.h"

@interface AppDelegate ()
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

        options.sessionReplay.quality = SentryReplayQualityMedium;
        options.sessionReplay.maskAllText = true;
        options.sessionReplay.maskAllImages = true;
        options.sessionReplay.sessionSampleRate = 0;
        options.sessionReplay.onErrorSampleRate = 1;

        options.experimental.enableFileManagerSwizzling
            = ![args containsObject:@"--disable-filemanager-swizzling"];
        options.sessionReplay.enableViewRendererV2
            = ![args containsObject:@"--disable-experimental-view-renderer"];
        options.sessionReplay.enableFastViewRendering
            = ![args containsObject:@"--disable-fast-view-renderer"];

        options.initialScope = ^(SentryScope *scope) {
            [scope setTagValue:@"" forKey:@""];
            [scope injectGitInformation];
            return scope;
        };

        if (@available(iOS 13.0, *)) {
            options.configureUserFeedback = ^(SentryUserFeedbackConfiguration *_Nonnull config) {
                UIOffset layoutOffset = UIOffsetMake(25, 75);
                if ([args containsObject:@"--io.sentry.feedback.all-defaults"]) {
                    config.configureWidget = ^(SentryUserFeedbackWidgetConfiguration *widget) {
                        widget.layoutUIOffset = layoutOffset;
                    };
                    return;
                }
                config.useShakeGesture = YES;
                config.showFormForScreenshots = YES;
                config.configureWidget = ^(SentryUserFeedbackWidgetConfiguration *_Nonnull widget) {
                    if ([args containsObject:@"--io.sentry.feedback.no-auto-inject-widget"]) {
                        widget.autoInject = NO;
                    } else {
                        widget.labelText = @"Report Jank";
                        widget.layoutUIOffset = layoutOffset;
                    }

                    if ([args containsObject:@"--io.sentry.feedback.no-widget-text"]) {
                        widget.labelText = nil;
                    }
                    if ([args containsObject:@"--io.sentry.feedback.no-widget-icon"]) {
                        widget.showIcon = NO;
                    }
                };
                config.configureForm = ^(SentryUserFeedbackFormConfiguration *_Nonnull uiForm) {
                    uiForm.formTitle = @"Jank Report";
                    uiForm.submitButtonLabel = @"Report that jank";
                    uiForm.messagePlaceholder
                        = @"Describe the nature of the jank. Its essence, if you will.";
                    uiForm.useSentryUser = YES;
                };
                config.configureTheme = ^(SentryUserFeedbackThemeConfiguration *_Nonnull theme) {
                    theme.font = [UIFont fontWithName:@"ChalkboardSE-Regular" size:25];
                    theme.outlineStyle =
                        [[SentryFormElementOutlineStyle alloc] initWithColor:UIColor.purpleColor
                                                                cornerRadius:10
                                                                outlineWidth:4];
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
                                         message:
                                             [NSString stringWithFormat:
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
        }
    }];

    return YES;
}

#pragma mark - UISceneSession lifecycle

@end
