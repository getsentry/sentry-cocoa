#import "ViewController.h"
@import SentryObjC;

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [SentryObjCSDK addBreadcrumb:[[SentryObjCBreadcrumb alloc] init]];
}

- (IBAction)captureError:(id)sender
{
    NSError *error = [NSError errorWithDomain:@"iOS-ObjectiveC-Dynamic" code:1 userInfo:nil];
    [SentryObjCSDK captureError:error];
}

@end
