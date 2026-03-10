// Objective-C++ file - uses SentryObjC for full SDK access without modules.

#import "ViewController.h"
#import <SentryObjC.h>
#import <UIKit/UIKit.h>

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [SentryObjCSDK addBreadcrumb:[[SentryBreadcrumb alloc] init]];
}

- (IBAction)captureError:(id)sender
{
    NSError *error = [NSError errorWithDomain:@"iOS-ObjectiveCpp-NoModules" code:1 userInfo:nil];
    [SentryObjCSDK captureError:error];
}

@end
