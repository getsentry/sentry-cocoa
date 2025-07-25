#import "ViewController.h"
#import "NoARCCrash.h"

@import Sentry;
@import SentrySampleShared;

@interface ViewController ()

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

        NSString *path = [[NSBundle mainBundle] pathForResource:@"Tongariro" ofType:@"jpg"];
        [scope addAttachment:[[SentryAttachment alloc] initWithPath:path
                                                           filename:@"Tongariro.jpg"
                                                        contentType:@"image/jpeg"]];

        [scope addAttachment:[[SentryAttachment alloc]
                                 initWithData:[@"hello" dataUsingEncoding:NSUTF8StringEncoding]
                                     filename:@"log.txt"]];
    }];
    // Also works
    SentryUser *user = [[SentryUser alloc] initWithUserId:@"1"];
    user.email = @"tony@example.com";
    [SentrySDK setUser:user];

    // Load an image just for HTTP swizzling
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    NSURL *url = [[NSURL alloc]
        initWithString:@"https://sentry-brand.storage.googleapis.com/sentry-logo-black.png"];
    NSURLSessionDataTask *task = [session dataTaskWithURL:url];
    [task resume];
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

#if SDK_V9
    NSLog(@"SDK V9 does not support user feedback.");
#else
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wdeprecated-declarations"
    SentryUserFeedback *userFeedback = [[SentryUserFeedback alloc] initWithEventId:eventId];
#    pragma clang diagnostic pop
    userFeedback.comments = @"It broke on iOS-ObjectiveC. I don't know why, but this happens.";
    userFeedback.email = @"john@me.com";
    userFeedback.name = @"John Me";
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [SentrySDK captureUserFeedback:userFeedback];
#    pragma clang diagnostic pop
#endif // SDK_V9
}

- (IBAction)captureUserFeedbackV2:(id)sender
{
    NSData *data = [NSData dataWithContentsOfURL:BundleResourceProvider.screenshotURL];
    NSArray<NSData *> *attachments = nil;
    if (data != nil) {
        attachments = @[ data ];
    }
    SentryId *errorEventID =
        [SentrySDK captureError:[NSError errorWithDomain:@"test-error.user-feedback.iOS-ObjectiveC"
                                                    code:1
                                                userInfo:nil]];
    SentryFeedback *feedback = [[SentryFeedback alloc]
          initWithMessage:@"It broke again on iOS-ObjectiveC. I don't know why, but this happens."
                     name:@"John Me"
                    email:@"john@me.com"
                   source:SentryFeedbackSourceCustom
        associatedEventId:errorEventID
              attachments:attachments];
    [SentrySDK captureFeedback:feedback];
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
    // !!!: By explicity just passing the scope, only the data in this scope object will be added to
    // the event; the global scope (calls to configureScope) will be ignored. If you do that, be
    // careful–a lot of useful info is lost. If you just want to mutate what's in the scope use the
    // callback, see: captureError.
    [SentrySDK captureException:exception withScope:scope];
}

- (IBAction)captureTransaction:(id)sender
{
    __block id<SentrySpan> fakeTransaction = [SentrySDK startTransactionWithName:@"Some Transaction"
                                                                       operation:@"some operation"];

    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(arc4random_uniform(100) + 400 * NSEC_PER_MSEC)),
        dispatch_get_main_queue(), ^{ [fakeTransaction finish]; });
}

- (IBAction)crash:(id)sender
{
    [SentrySDK crash];
}

- (IBAction)sigsevCrash:(id)sender
{
    callMessageOnDeallocatedObject();
}

- (IBAction)oomCrash:(id)sender
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSUInteger megaByte = 1024 * 1024;
        NSUInteger memoryPageSize = NSPageSize();
        NSUInteger memoryPages = megaByte / memoryPageSize;

        while (1) {
            // Allocate one MB and set one element of each memory page to something.
            volatile char *ptr = malloc(megaByte);
            for (int i = 0; i < memoryPages; i++) {
                ptr[i * memoryPageSize] = 'b';
            }
        }
    });
}

@end
