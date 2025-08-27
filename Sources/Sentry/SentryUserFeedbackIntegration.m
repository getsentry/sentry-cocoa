#import "SentryUserFeedbackIntegration.h"
#import "SentryDependencyContainer.h"
#import "SentryInternalDefines.h"
#import "SentryOptions+Private.h"
#import "SentrySDK+Private.h"
#import "SentrySwift.h"

#if TARGET_OS_IOS && SENTRY_HAS_UIKIT

@interface SentryUserFeedbackIntegration () <SentryUserFeedbackIntegrationDriverDelegate>
@end

@implementation SentryUserFeedbackIntegration {
    SentryUserFeedbackIntegrationDriver *_driver;
}

- (BOOL)installWithOptions:(SentryOptions *)options
{
    if (options.userFeedbackConfiguration == nil) {
        return NO;
    }

    SentryViewScreenshotProvider *screenshotProvider = [SentryDependencyContainer.sharedInstance
        getScreenshotProviderForOptions:options.screenshot];
    _driver = [[SentryUserFeedbackIntegrationDriver alloc]
        initWithConfiguration:SENTRY_UNWRAP_NULLABLE(SentryUserFeedbackConfiguration,
                                  options.userFeedbackConfiguration)
                     delegate:self
           screenshotProvider:screenshotProvider];
    return YES;
}

- (void)showWidget
{
    [_driver showWidget];
}

- (void)hideWidget
{
    [_driver hideWidget];
}

// MARK: SentryUserFeedbackIntegrationDriverDelegate

- (void)captureWithFeedback:(SentryFeedback *)feedback
{
    [SentrySDK captureFeedback:feedback];
}

@end

#endif // TARGET_OS_IOS && SENTRY_HAS_UIKIT
