#import "ViewController.h"
#import <SentryObjC.h>

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [SentryObjCSDK addBreadcrumb:[[SentryObjCBreadcrumb alloc] init]];
}

- (IBAction)captureError:(id)sender
{
    NSError *error = [NSError errorWithDomain:@"iOS-ObjectiveC-Static" code:1 userInfo:nil];
    [SentryObjCSDK captureError:error];
}

@end
