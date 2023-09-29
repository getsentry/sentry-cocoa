#if UIKIT_LINKED

#    import "SentryUIViewControllerSwizzling.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryUIViewControllerSwizzling (Test)

- (BOOL)shouldSwizzleViewController:(Class)class;

- (void)swizzleViewControllerSubClass:(Class)class;

- (void)swizzleRootViewControllerFromSceneDelegateNotification:(NSNotification *)notification;

- (void)swizzleRootViewControllerAndDescendant:(UIViewController *)rootViewController;

- (BOOL)swizzleRootViewControllerFromUIApplication:(SentryUIApplication *)app;

- (void)swizzleAllSubViewControllersInApp:(SentryUIApplication *)app;

- (void)swizzleUIViewControllersOfClassesInImageOf:(nullable Class)class;

- (void)swizzleUIViewControllersOfImage:(NSString *)imageName;
@end

NS_ASSUME_NONNULL_END

#endif // UIKIT_LINKED
