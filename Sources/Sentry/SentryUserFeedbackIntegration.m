#import "SentryUserFeedbackIntegration.h"

#if SENTRY_HAS_UIKIT

#    import "SentryUserFeedbackWidgetConfiguration.h"

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
    // Implementation for creating the widget UI and injecting it into the app's view hierarchy.
    NSLog(@"Creating feedback widget with ID: %@", self.configuration.widgetId);

    // Example of how the form might be created and shown
    [self showFeedbackForm];
}

- (void)removeFromDom
{
    // Implementation for removing the widget from the app's view hierarchy.
    NSLog(@"Removing feedback widget with ID: %@", self.configuration.widgetId);

    // Call the form close callback if defined
    if (self.configuration.onFormClose) {
        self.configuration.onFormClose();
    }
}

- (void)captureFeedback:(NSString *)message
                   name:(NSString *)name
                  email:(NSString *)email
                  hints:(NSDictionary *)hints
{
    if (message == nil || [message isEqualToString:@""]) {
        NSLog(@"Feedback message is required.");
        return;
    }

    // Simulate capturing feedback, e.g., sending it to a server
    NSLog(@"Capturing feedback: %@, Name: %@, Email: %@", message, name, email);

    // Simulate success callback
    if (self.configuration.onSubmitSuccess) {
        NSDictionary *data =
            @{ @"message" : message, @"name" : name ?: @"", @"email" : email ?: @"" };
        self.configuration.onSubmitSuccess(data);
    }

    // ... to be continued...
}

@end

#endif // SENTRY_HAS_UIKIT
