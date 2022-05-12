#import "SentryScreenshot.h"
#import "SentryDependencyContainer.h"
#import "SentryUIApplication.h"

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>

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

@end

#endif
