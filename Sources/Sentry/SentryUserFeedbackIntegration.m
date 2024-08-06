#import "SentryUserFeedbackIntegration.h"

#if SENTRY_HAS_UIKIT

#    import "SentryUserFeedbackConfiguration.h"

@interface
SentryUserFeedbackIntegration ()

@property (strong, nonatomic) SentryUserFeedbackConfiguration *configuration;

@end

@implementation SentryUserFeedbackIntegration

- (instancetype)initWithConfiguration:(SentryUserFeedbackConfiguration *)configuration
{
    self = [super init];
    if (self) {
        _configuration = configuration;
    }
    return self;
}

- (void)showModal
{
    // TODO: implement
}

@end

#endif // SENTRY_HAS_UIKIT
