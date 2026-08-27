#import "AppDelegate.h"
@import CoreData;
@import SentryObjC;
@import SentrySampleShared;

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
        [SentrySampleDataCollectionConfiguration configureWithObjCOptions:options];

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

        SentryObjCReplayOptions *sessionReplay = [[SentryObjCReplayOptions alloc] init];
        sessionReplay.sessionSampleRate = 0;
        sessionReplay.onErrorSampleRate = 1;
        sessionReplay.maskAllText = YES;
        sessionReplay.maskAllImages = YES;
        sessionReplay.enableViewRendererV2 = ![args containsObject:@"--disable-view-renderer-v2"];
        sessionReplay.enableFastViewRendering
            = ![args containsObject:@"--disable-fast-view-rendering"];
        options.sessionReplay = sessionReplay;

        options.enableFileManagerSwizzling
            = ![args containsObject:@"--disable-filemanager-swizzling"];

        options.initialScope = ^SentryObjCScope *(SentryObjCScope *scope) {
            [scope setTagValue:@"" forKey:@""];
            NSDictionary *info = NSBundle.mainBundle.infoDictionary;
            NSString *commitHash = info[@"GIT_COMMIT_HASH"];
            if (commitHash.length > 0) {
                BOOL gitStatusClean = [info[@"GIT_STATUS_CLEAN"] isEqualToString:@"1"];
                [scope setTagValue:[NSString stringWithFormat:@"%@%@", commitHash,
                                       gitStatusClean ? @"" : @"-dirty"]
                            forKey:@"git-commit-hash"];
            }
            NSString *branchName = info[@"GIT_BRANCH"];
            if (branchName.length > 0) {
                [scope setTagValue:branchName forKey:@"git-branch-name"];
            }
            return scope;
        };

        options.configureUserFeedback = ^(SentryObjCUserFeedbackConfiguration *_Nonnull config) {
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
            config.configureTheme = ^(SentryObjCUserFeedbackThemeConfiguration *_Nonnull theme) {
                theme.fontFamily = @"ChalkboardSE-Regular";
                theme.outlineStyle = [[SentryObjCUserFeedbackFormElementOutlineStyle alloc]
                    initWithColor:UIColor.purpleColor
                     cornerRadius:10
                     outlineWidth:4];
            };
            config.onSubmitSuccess = ^(NSDictionary<NSString *, id> *_Nonnull info) {
                NSLog(@"Feedback submitted successfully: %@", info);
            };
            config.onSubmitError
                = ^(NSError *_Nonnull error) { NSLog(@"Failed to submit feedback: %@", error); };
        };
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
