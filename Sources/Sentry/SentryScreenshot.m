#import "SentryScreenshot.h"
#import "SentryDependencyContainer.h"
#import "SentryUIApplication.h"

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>

void
saveScreenShots(const char *path)
{
    [SentryDependencyContainer.sharedInstance.screenshot
        saveScreenShots:[NSString stringWithUTF8String:path]];
}

@implementation SentryScreenshot

- (NSArray<NSData *> *)appScreenshots
{
    __block NSMutableArray *result;

    void (^takeScreenShot)(void) = ^{
        NSArray<UIWindow *> *windows =
            [SentryDependencyContainer.sharedInstance.application windows];

        result = [NSMutableArray arrayWithCapacity:windows.count];

        for (UIWindow *window in windows) {
            UIGraphicsBeginImageContext(window.frame.size);

            if ([window drawViewHierarchyInRect:window.bounds afterScreenUpdates:false]) {
                UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
                [result addObject:UIImagePNGRepresentation(img)];
            }

            UIGraphicsEndImageContext();
        }
    };

    if ([NSThread isMainThread]) {
        takeScreenShot();
    } else {
        dispatch_sync(dispatch_get_main_queue(), takeScreenShot);
    }

    return result;
}

- (void)saveScreenShots:(NSString *)path
{
    NSArray<UIWindow *> *windows = [SentryDependencyContainer.sharedInstance.application windows];

    for (UIWindow *window in windows) {
        UIGraphicsBeginImageContext(window.frame.size);

        int index = 0;
        if ([window drawViewHierarchyInRect:window.bounds afterScreenUpdates:false]) {
            UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
            NSString *name = index == 0
                ? @"screenshot.png"
                : [NSString stringWithFormat:@"screenshot-%i.png", index++ + 1];
            NSString *fileName = [path stringByAppendingPathComponent:name];
            [UIImagePNGRepresentation(img) writeToFile:fileName atomically:YES];
        }

        UIGraphicsEndImageContext();
    }
}

@end

#endif
