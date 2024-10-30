#import "SentryUserFeedbackIntegration.h"
#import "SentryOptions+Private.h"
#import "SentrySwift.h"

#if TARGET_OS_IOS && SENTRY_HAS_UIKIT

@implementation SentryUserFeedbackIntegration {
    SentryUserFeedbackIntegration *_driver;
}

- (BOOL)installWithOptions:(SentryOptions *)options
{
    _driver = [[SentryUserFeedbackIntegration alloc]
        initWithConfiguration:options.userFeedbackConfiguration];
    return YES;
}

@end

#endif // TARGET_OS_IOS && SENTRY_HAS_UIKIT
