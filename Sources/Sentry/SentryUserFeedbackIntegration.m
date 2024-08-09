#import "SentryUserFeedbackIntegration.h"

#if SENTRY_HAS_UIKIT

#    import "SentryLog.h"
#    import "SentryUserFeedbackWidgetConfiguration.h"
#    import <UIKit/UIKit.h>

@interface
SentryUserFeedbackIntegration ()

@property (strong, nonatomic) SentryUserFeedbackWidgetConfiguration *configuration;

@end

@implementation SentryUserFeedbackIntegration

- (instancetype)initWithConfiguration:(SentryUserFeedbackWidgetConfiguration *)configuration
{
    self = [super init];
    if (self) {
        _configuration = configuration;
        if (_configuration.autoInject) {
            [self createWidget];
        }
    }
    return self;
}

- (void)createWidget
{
    // TODO: implement
}

- (void)removeWidget
{
    // TODO: implement
}

- (void)captureFeedback:(NSString *)message
                   name:(NSString *)name
                  email:(NSString *)email
                  hints:(NSDictionary *)hints
{
    // TODO: implement
}

- (void)attachToButton:(nonnull UIButton *)button
{
    // TODO: implement
}

@end

#endif // SENTRY_HAS_UIKIT
