#import "SentryUIViewControllerSwizziling.h"

NS_ASSUME_NONNULL_BEGIN

#if SENTRY_HAS_UIKIT

@interface
SentryUIViewControllerSwizziling (Test)

- (BOOL)shouldSwizzleViewController:(Class)class;

- (void)swizzleViewControllerSubClass:(Class)class;

- (void)swizzleRootViewControllerFromSceneDelegateNotification:(NSNotification *)notification;

- (void)swizzleRootViewControllerAndDescendant:(UIViewController *)rootViewController;

@end

#endif

NS_ASSUME_NONNULL_END
