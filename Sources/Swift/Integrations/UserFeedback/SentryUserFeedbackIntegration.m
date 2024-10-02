#import "SentryUserFeedbackIntegration.h"
#import "SentryOptions+Private.h"
#import "SentrySwift.h"

@implementation SentryUserFeedbackIntegration {
    SentryUserFeedbackIntegrationDriver *_driver;
}

- (BOOL)installWithOptions:(SentryOptions *)options
{
    _driver = [[SentryUserFeedbackIntegrationDriver alloc]
        initWithConfiguration:options.userFeedbackConfiguration];
    return YES;
}

@end
