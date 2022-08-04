#import "SentryViewHierarchy.h"
#import "SentryDependencyContainer.h"
#import "SentryUIApplication.h"

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>

@interface
UIView (Debugging)
- (id)recursiveDescription;
@end

@implementation SentryViewHierarchy

+ (void)fetchViewHierarchy
{
    NSArray<UIWindow *> *windows = [SentryDependencyContainer.sharedInstance.application windows];

    for (UIWindow *window in windows) {
        NSString *description = [window recursiveDescription];
        NSLog(@"%@", description);
    }
}

@end

#endif
