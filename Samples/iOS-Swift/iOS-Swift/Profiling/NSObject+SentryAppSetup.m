#import "NSObject+SentryAppSetup.h"

@implementation
NSObject (SentryAppSetup)
+ (void)load
{
    NSLog(@"[iOS-Swift] Starting app launch work");
    if ([NSProcessInfo.processInfo.arguments containsObject:@"--io.sentry.slow-load-method"]) {
        NSMutableString *a = [NSMutableString string];
        // 1,000,000 iterations takes about 225 milliseconds in the iPhone 15 simulator on an
        // M2 macbook pro; we might have to adapt this for CI
        for (NSUInteger i = 0; i < 4000000; i++) {
            [a appendFormat:@"%d", arc4random() % 12345];
        }
    }
    NSLog(@"[iOS-Swift] Finishing app launch work");
}
@end
