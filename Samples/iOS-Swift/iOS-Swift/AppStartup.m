#import "AppStartup.h"

@implementation AppStartup

// we must do this in objective c, because it's not permitted to be overridden in Swift
+ (void)load
{
    if ([NSProcessInfo.processInfo.arguments containsObject:@"--io.sentry.wipe-data"]) {
        NSLog(@"[iOS-Swift] removing app data");
        NSString *appSupport = [NSSearchPathForDirectoriesInDomains(
            NSApplicationSupportDirectory, NSUserDomainMask, true) firstObject];
        NSString *cache = [NSSearchPathForDirectoriesInDomains(
            NSCachesDirectory, NSUserDomainMask, true) firstObject];
        NSFileManager *fm = NSFileManager.defaultManager;
        for (NSString *dir in @[ appSupport, cache ]) {
            for (NSString *file in [fm enumeratorAtPath:dir]) {
                NSError *error;
                if (![fm removeItemAtPath:[dir stringByAppendingPathComponent:file] error:&error]) {
                    NSLog(@"[iOS-Swift] failed to remove data at app startup.");
                }
            }
        }
    }
}

@end
