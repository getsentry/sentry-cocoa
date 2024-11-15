#import "SentryUserFeedbackIntegration.h"
#import "SentryOptions+Private.h"
#import "SentrySwift.h"
#import "SentryEnvelope.h"
#import "SentrySDK+Private.h"
#import "SentryUserFeedback.h"

#if TARGET_OS_IOS && SENTRY_HAS_UIKIT

@interface SentryUserFeedbackIntegration() <SentryUserFeedbackIntegrationDriverDelegate>

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
               initWithConfiguration:options.userFeedbackConfiguration delegate:self];
    return YES;
}

#pragma mark - SentryUserFeedbackIntegrationDriverDelegate

- (void)captureFeedbackWithMessage:(NSString * _Nonnull)message name:(NSString * _Nullable)name email:(NSString * _Nullable)email hints:(NSDictionary<NSString *,id> * _Nullable)hints {
    NSError *error = [[NSError alloc] initWithDomain:@"user-feedback" code:1 userInfo:nil];
    SentryId *eventId = [SentrySDK captureError:error];
//    SentryId *eventId = [[SentryId alloc] init];
    SentryUserFeedback *uf = [[SentryUserFeedback alloc] initWithEventId:eventId];
    uf.name = name;
    uf.comments = message;
    uf.email = email;
    [SentrySDK captureUserFeedback:uf];
}

@end

#endif // TARGET_OS_IOS && SENTRY_HAS_UIKIT
