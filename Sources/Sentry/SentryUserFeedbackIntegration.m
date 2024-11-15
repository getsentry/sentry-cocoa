#import "SentryUserFeedbackIntegration.h"
#import "SentryOptions+Private.h"
#import "SentrySwift.h"
#import "SentryEnvelope.h"
#import "SentrySDK+Private.h"
#import "SentryUserFeedback.h"

#if TARGET_OS_IOS && SENTRY_HAS_UIKIT

@interface SentryUserFeedbackIntegration()

@end

@implementation SentryUserFeedbackIntegration {
    SentryUserFeedbackIntegrationDriver *_driver;
}

- (BOOL)installWithOptions:(SentryOptions *)options
{
    if (options.userFeedbackConfiguration == nil) {
        return NO;
    }

    _driver = [[SentryUserFeedbackIntegrationDriver alloc]
               initWithConfiguration:options.userFeedbackConfiguration];
    return YES;
}

@end

#endif // TARGET_OS_IOS && SENTRY_HAS_UIKIT
