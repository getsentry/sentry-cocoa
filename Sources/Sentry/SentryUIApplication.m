#import "SentryUIApplication.h"

#if SENTRY_HAS_UIKIT

#    import <UIKit/UIKit.h>

@implementation SentryUIApplication

- (UIApplication *)sharedApplication
{
    if (![UIApplication respondsToSelector:@selector(sharedApplication)])
        return nil;

    return [UIApplication performSelector:@selector(sharedApplication)];
}

- (nullable id<UIApplicationDelegate>)getApplicationDelegate:(UIApplication *)application
{
    return application.delegate;
}

- (NSArray<UIScene *> *)getApplicationConnectedScenes:(UIApplication *)application
    API_AVAILABLE(ios(13.0), tvos(13.0))
{
    if (application && [application respondsToSelector:@selector(connectedScenes)]) {
        return [application.connectedScenes allObjects];
    }

    return @[];
}

- (NSArray<UIWindow *> *)windows
{
    UIApplication *app = [self sharedApplication];
    NSMutableArray *result = [NSMutableArray array];

    if (@available(iOS 13.0, tvOS 13.0, *)) {
        NSArray<UIScene *> *scenes = [self getApplicationConnectedScenes:app];
        for (UIScene *scene in scenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive && scene.delegate &&
                [scene.delegate respondsToSelector:@selector(window)]) {
                id window = [scene.delegate performSelector:@selector(window)];
                if (window) {
                    [result addObject:window];
                }
            }
        }
    }

    id<UIApplicationDelegate> appDelegate = [self getApplicationDelegate:app];

    if ([appDelegate respondsToSelector:@selector(window)] && appDelegate.window != nil) {
        [result addObject:appDelegate.window];
    }

    return result;
}

- (NSArray<UIViewController *> *)relevantViewControllers
{
    NSArray<UIWindow *> *windows = [self windows];
    if ([windows count] == 0) {
        return nil;
    }
        
    NSMutableArray *result = [NSMutableArray array];

    for (UIWindow *window in windows) {
        NSArray<UIViewController *> *vcs = [self relevantViewControllerFromWindow:window];
        if (vcs != nil) {
            [result addObjectsFromArray:vcs];
        }
    }

    return result;
}

- (NSArray<UIViewController *> *)relevantViewControllerFromWindow:(UIWindow *)window
{
    UIViewController *rootViewController = window.rootViewController;
    if (rootViewController == nil) {
        return nil;
    }

    NSMutableArray<UIViewController *> *result = [NSMutableArray<UIViewController *> arrayWithObject:rootViewController];
    NSUInteger index = 0;

    while (index < result.count) {
        UIViewController *topVC = result[index];
        // If the view controller is presenting another one, usually in a modal form.
        if (topVC.presentedViewController != nil) {
            [result replaceObjectAtIndex:index withObject:topVC.presentedViewController];
            continue;
        }

        // The top view controller is meant for navigation and not content
        if ([self isContainerViewController:topVC]) {
            [result removeObjectAtIndex:index];
            [result addObjectsFromArray:[self relevantViewControllerFromContainer:topVC]];
            continue;
        }

        UIViewController *relevantChild = nil;
        for (UIViewController *childVC in topVC.childViewControllers) {
            // Sometimes a view controller is used as container for a navigation controller
            // If the navigation is occupying the whole view controller we will consider this the
            // case.
            if ([self isContainerViewController:childVC]
                && CGRectEqualToRect(childVC.view.frame, topVC.view.bounds)) {
                relevantChild = childVC;
                break;
            }
        }

        if (relevantChild != nil) {
            [result replaceObjectAtIndex:index withObject:topVC];
            continue;
        }

        index++;
    }

    return result;
}

- (BOOL)isContainerViewController:(UIViewController *)viewController
{
    return [viewController isKindOfClass:UINavigationController.class] ||
        [viewController isKindOfClass:UITabBarController.class] ||
        [viewController isKindOfClass:UISplitViewController.class] ||
        [viewController isKindOfClass:UIPageViewController.class];
}

- (nullable NSArray<UIViewController *> *)relevantViewControllerFromContainer:
    (UIViewController *)containerVC
{
    if ([containerVC isKindOfClass:UINavigationController.class]) {
        return @[ [(UINavigationController *)containerVC topViewController] ];
    }
    if ([containerVC isKindOfClass:UITabBarController.class]) {
        UITabBarController *tbController = (UITabBarController *)containerVC;
        return @[ [tbController.viewControllers objectAtIndex:tbController.selectedIndex] ];
    }
    if ([containerVC isKindOfClass:UISplitViewController.class]) {
        UISplitViewController *splitVC = (UISplitViewController *)containerVC;
        if (splitVC.viewControllers.count > 1) {
            return [splitVC viewControllers];
        }
    }
    if ([containerVC isKindOfClass:UIPageViewController.class]) {
        UIPageViewController *pageVC = (UIPageViewController *)containerVC;
        if (pageVC.viewControllers.count > 0) {
            return @[ [[pageVC viewControllers] objectAtIndex:0] ];
        }
    }
    return nil;
}

- (UIApplicationState)applicationState
{
    return self.sharedApplication.applicationState;
}

@end

#endif // SENTRY_HAS_UIKIT
