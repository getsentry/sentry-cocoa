#if __has_include(<Sentry/SentryDefines.h>)
#    import <Sentry/SentryDefines.h>
#elif __has_include(<SentryWithoutUIKit/Sentry.h>)
#    import <SentryWithoutUIKit/SentryDefines.h>
#else
#    import <SentryDefines.h>
#endif

#if TARGET_OS_IOS && SENTRY_HAS_UIKIT

#    import "SentryFeedbackAPI.h"
#    import "SentryHub+Private.h"
#    import "SentryLogC.h"
#    import "SentrySDK+Private.h"
#    import "SentryUserFeedbackIntegration.h"

@implementation SentryFeedbackAPI

- (void)showWidget
{
    SentryUserFeedbackIntegration *feedback = [[SentrySDKInternal currentHub]
        getInstalledIntegration:[SentryUserFeedbackIntegration class]];
    [feedback showWidget];
}

- (void)hideWidget
{
    SentryUserFeedbackIntegration *feedback = [SentrySDKInternal.currentHub
        getInstalledIntegration:[SentryUserFeedbackIntegration class]];
    [feedback hideWidget];
}

@end

#endif // TARGET_OS_IOS && SENTRY_HAS_UIKIT
