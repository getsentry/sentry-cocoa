#import "SentryScreenShot.h"
#import "SentryUIApplication.h"

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>

@implementation SentryScreenshot

- (NSArray<NSData *> *)appScreenshots
{
    NSArray<UIWindow *> *windows = [SentryUIApplication windows];

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
