#import "AppDelegate.h"
@import CoreData;
@import Sentry;

@import SentrySampleShared;

@interface AppDelegate ()
@property (strong, nonatomic) SampleAppDebugMenu *debugMenu;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.debugMenu = [[SampleAppDebugMenu alloc] init];
    [self.debugMenu display];

    NSArray<NSString *> *args = NSProcessInfo.processInfo.arguments;
    NSDictionary<NSString *, NSString *> *env = NSProcessInfo.processInfo.environment;

    [SentrySDK startWithConfigureOptions:^(SentryOptions *options) {
        options.dsn = @"https://6cc9bae94def43cab8444a99e0031c28@o447951.ingest.sentry.io/5428557";
        options.debug = YES;
        options.attachScreenshot = YES;
        options.attachViewHierarchy = YES;

        if (env[@"--io.sentry.tracesSamplerValue"] != nil) {
            options.tracesSampler = ^(SentrySamplingContext *_Nonnull samplingContext) {
                return @([env[@"--io.sentry.tracesSamplerValue"] doubleValue]);
            };
        }

        options.tracesSampleRate = @1.0;
        if (env[@"--io.sentry.tracesSampleRate"] != nil) {
            options.tracesSampleRate = @([env[@"--io.sentry.tracesSampleRate"] doubleValue]);
        }

        if (![args containsObject:@"--io.sentry.profiling.disable-ui-profiling"]) {
            options.configureProfiling = ^(SentryProfileOptions *_Nonnull profiling) {
                profiling.lifecycle =
                    [args containsObject:@"--io.sentry.profiling.profile-lifecycle-manual"]
                    ? SentryProfileLifecycleManual
                    : SentryProfileLifecycleTrace;

                profiling.sessionSampleRate = 1.f;
                if (env[@"--io.sentry.profiling.profile-session-sample-rate"] != nil) {
                    profiling.sessionSampleRate =
                        [env[@"--io.sentry.profiling.profile-session-sample-rate"] floatValue];
                }
            };
        }

#if !SDK_V9
        if (env[@"--io.sentry.profiling.profilesSampleRate"] != nil) {
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wdeprecated-declarations"
            options.profilesSampleRate =
                @([env[@"--io.sentry.profiling.profilesSampleRate"] floatValue]);
#    pragma clang diagnostic pop
        }

        if (env[@"--io.sentry.profilesSamplerValue"] != nil) {
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wdeprecated-declarations"
            options.profilesSampler
                = ^NSNumber *_Nullable(SentrySamplingContext *_Nonnull samplingContext)
            {
                return @([env[@"--io.sentry.profilesSamplerValue"] floatValue]);
            };
#    pragma clang diagnostic pop
        }

        if (![args containsObject:@"--io.sentry.profiling.disable-app-start-profiling"]) {
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wdeprecated-declarations"
            options.enableAppLaunchProfiling = YES;
#    pragma clang diagnostic pop
        }
#endif // !SDK_V9

        SentryHttpStatusCodeRange *httpStatusCodeRange =
            [[SentryHttpStatusCodeRange alloc] initWithMin:400 max:599];
        options.failedRequestStatusCodes = @[ httpStatusCodeRange ];

        options.sessionReplay = [[SentryReplayOptions alloc]
            initWithSessionSampleRate:0
                    onErrorSampleRate:1
                          maskAllText:true
                        maskAllImages:true
                 enableViewRendererV2:![args containsObject:@"--disable-view-renderer-v2"]
              enableFastViewRendering:![args containsObject:@"--disable-fast-view-rendering"]];

        options.experimental.enableFileManagerSwizzling
            = ![args containsObject:@"--disable-filemanager-swizzling"];

        options.initialScope = ^(SentryScope *scope) {
            [scope setTagValue:@"" forKey:@""];
            [GitInjector objc_injectGitInformationInto:scope];
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
                    theme.fontFamily = @"ChalkboardSE-Regular";
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
