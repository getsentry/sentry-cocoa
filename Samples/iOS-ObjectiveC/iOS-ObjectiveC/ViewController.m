#import "ViewController.h"
@import Sentry;

@interface
ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [SentrySDK configureScope:^(SentryScope *_Nonnull scope) {
        [scope setEnvironment:@"debug"];
        [scope setTagValue:@"objc" forKey:@"language"];
        [scope setExtraValue:[NSString stringWithFormat:@"%@", self]
                      forKey:@"currentViewController"];
        SentryUser *user = [[SentryUser alloc] initWithUserId:@"1"];
        user.email = @"tony@example.com";
        [scope setUser:user];
    }];
    // Also works
    SentryUser *user = [[SentryUser alloc] initWithUserId:@"1"];
    user.email = @"tony@example.com";
    [SentrySDK setUser:user];
}

- (IBAction)addBreadcrumb:(id)sender
{
    SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] init];
    crumb.message = @"tapped addBreadcrumb";
    [SentrySDK addBreadcrumb:crumb];
}

- (IBAction)captureMessage:(id)sender
{
    SentryId *eventId = [SentrySDK captureMessage:@"Yeah captured a message"];
    // Returns eventId in case of successful processed event
    // otherwise emptyId
    NSLog(@"%@", eventId);
}

- (IBAction)captureUserFeedback:(id)sender
{
    NSError *error =
        [[NSError alloc] initWithDomain:@"UserFeedbackErrorDomain"
                                   code:0
                               userInfo:@{ NSLocalizedDescriptionKey : @"This never happens." }];
    SentryId *eventId = [SentrySDK
          captureError:error
        withScopeBlock:^(SentryScope *_Nonnull scope) { [scope setLevel:kSentryLevelFatal]; }];

    SentryUserFeedback *userFeedback = [[SentryUserFeedback alloc] initWithEventId:eventId];
    userFeedback.comments = @"It broke on iOS-ObjectiveC. I don't know why, but this happens.";
    userFeedback.email = @"john@me.com";
    userFeedback.name = @"John Me";
    [SentrySDK captureUserFeedback:userFeedback];
}

- (IBAction)captureError:(id)sender
{
    NSError *error =
        [[NSError alloc] initWithDomain:@"SampleErrorDomain"
                                   code:0
                               userInfo:@{ NSLocalizedDescriptionKey : @"Object does not exist" }];
    [SentrySDK captureError:error
             withScopeBlock:^(SentryScope *_Nonnull scope) {
                 // Changes in here will only be captured for this event
                 // The scope in this callback is a clone of the current scope
                 // It contains all data but mutations only influence the event
                 // being sent
                 [scope setTagValue:@"value" forKey:@"myTag"];
             }];
}

- (IBAction)captureException:(id)sender
{
    NSException *exception = [[NSException alloc] initWithName:@"My Custom exception"
                                                        reason:@"User clicked the button"
                                                      userInfo:nil];
    SentryScope *scope = [[SentryScope alloc] init];
    [scope setLevel:kSentryLevelFatal];
    // By explicitly just passing the scope, only the data in this scope object
    // will be added to the event The global scope (calls to configureScope)
    // will be ignored Only do this if you know what you are doing, you loose a
    // lot of useful info If you just want to mutate what's in the scope use the
    // callback, see: captureError
    [SentrySDK captureException:exception withScope:scope];
}

- (IBAction)crash:(id)sender
{
    [SentrySDK crash];
}

@end
