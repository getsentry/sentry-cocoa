#import "UIViewController+Sentry.h"

#if SENTRY_HAS_UIKIT

@implementation
UIViewController (Sentry)

+ (void)load
{
    printf("%llu %s\n", clock_gettime_nsec_np(CLOCK_UPTIME_RAW), __PRETTY_FUNCTION__);
}

- (NSArray<UIViewController *> *)sentry_descendantViewControllers
{

    // The implementation of UIViewController makes sure a parent can't be a child of his child.
    // Therefore, we can assume the parent child relationship is correct.

    NSMutableArray<UIViewController *> *allViewControllers = [NSMutableArray new];
    [allViewControllers addObject:self];

    NSMutableArray<UIViewController *> *toAdd =
        [NSMutableArray arrayWithArray:self.childViewControllers];

    while (toAdd.count > 0) {
        UIViewController *viewController = [toAdd lastObject];
        [allViewControllers addObject:viewController];
        [toAdd removeLastObject];
        [toAdd addObjectsFromArray:viewController.childViewControllers];
    }

    return allViewControllers;
}

@end

#endif // SENTRY_HAS_UIKIT
