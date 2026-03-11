// Objective-C++ file - same module restrictions as AppDelegate.mm.
// Cannot use @import Sentry here; must use #import.
// No Sentry-Swift.h - would cause forward declaration errors from .mm without modules.

#import "ViewController.h"
#import <Sentry/Sentry.h>
#import <UIKit/UIKit.h>

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Fails: SentrySDK undeclared with #import alone
    [SentrySDK addBreadcrumb:[[SentryBreadcrumb alloc] init]];
}

- (IBAction)captureError:(id)sender
{
    NSError *error = [NSError errorWithDomain:@"iOS-ObjectiveCpp-NoModules" code:1 userInfo:nil];
    [SentrySDK captureError:error];
}

@end
