#import "SentryUserFeedbackIntegrationShell.h"
#import "SentryOptions+Private.h"
#import "SentrySwift.h"

@implementation SentryUserFeedbackIntegrationShell {
    SentryUserFeedbackIntegration *_driver;
}

- (BOOL)installWithOptions:(SentryOptions *)options
{
    _driver = [[SentryUserFeedbackIntegration alloc]
        initWithConfiguration:options.userFeedbackConfiguration];
    return YES;
}

@end
