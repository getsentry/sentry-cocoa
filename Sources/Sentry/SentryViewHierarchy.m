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

+ (NSArray<NSString *> *)fetchViewHierarchy
{
    NSArray<UIWindow *> *windows = [SentryDependencyContainer.sharedInstance.application windows];

    NSMutableArray *result = [NSMutableArray arrayWithCapacity:[windows count]];

    [windows enumerateObjectsUsingBlock:^(UIWindow *window, NSUInteger idx, BOOL *stop) {
        if ([NSThread isMainThread]) {
            [result addObject:[window recursiveDescription]];
        } else {
            dispatch_sync(
                dispatch_get_main_queue(), ^{ [result addObject:[window recursiveDescription]]; });
        }
    }];

    return result;
}

@end

#endif
