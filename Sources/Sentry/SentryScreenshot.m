#import "SentryScreenshot.h"
#import "SentryDependencyContainer.h"
#import "SentryUIApplication.h"

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>

@implementation SentryScreenshot

- (NSArray<NSData *> *)appScreenshots
{
    __block NSArray *result;

    void (^takeScreenShot)(void) = ^{ result = [self takeScreenshots]; };

    if ([NSThread isMainThread]) {
        takeScreenShot();
    } else {
        dispatch_sync(dispatch_get_main_queue(), takeScreenShot);
    }

    return result;
}

- (void)saveScreenShots:(NSString *)path
{
    // This function does not dispatch the screenshot to the main thread.
    // The caller should be aware of that.
    // We did it this way because we use this function to save screenshots
    // during signal handling, and if we dispatch it to the main thread,
    // that is probably blocked by the crash event, we freeze the application.
    [[self takeScreenshots] enumerateObjectsUsingBlock:^(NSData *obj, NSUInteger idx, BOOL *stop) {
        NSString *name
            = idx == 0 ? @"screenshot.png" : [NSString stringWithFormat:@"screenshot-%li.png", (unsigned long)idx + 1];
        NSString *fileName = [path stringByAppendingPathComponent:name];
        [obj writeToFile:fileName atomically:YES];
    }];
}

- (NSArray<NSData *> *)takeScreenshots
{
    NSArray<UIWindow *> *windows = [SentryDependencyContainer.sharedInstance.application windows];

    NSMutableArray *result = [NSMutableArray arrayWithCapacity:windows.count];

    for (UIWindow *window in windows) {
        UIGraphicsBeginImageContext(window.frame.size);

        if ([window drawViewHierarchyInRect:window.bounds afterScreenUpdates:false]) {
            UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
            [result addObject:UIImagePNGRepresentation(img)];
        }

        UIGraphicsEndImageContext();
    }
    return result;
}

@end

#endif
