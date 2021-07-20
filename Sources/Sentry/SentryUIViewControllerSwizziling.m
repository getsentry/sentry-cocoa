#import "SentryUIViewControllerSwizziling.h"
#import "SentryLog.h"
#import "SentryPerformanceTracker.h"
#import "SentrySwizzle.h"
#import "SentryUIViewControllerPerformanceTracker.h"
#import <UIViewController+Sentry.h>
#import <objc/runtime.h>

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>

@implementation SentryUIViewControllerSwizziling

+ (void)start
{
    [SentryUIViewControllerSwizziling swizzleViewControllerInits];
}

// SentrySwizzleInstanceMethod declaration shadows a local variable. The swizzling is working
// fine and we accept this warning.
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wshadow"

/**
 * Swizzle the some init methods of the view controller,
 * so we can swizzle user view controller subclass on demand.
 */
+ (void)swizzleViewControllerInits
{
    static const void *swizzleViewControllerInitWithCoder = &swizzleViewControllerInitWithCoder;
    SEL coderSelector = NSSelectorFromString(@"initWithCoder:");
    SentrySwizzleInstanceMethod(UIViewController.class, coderSelector, SentrySWReturnType(id),
        SentrySWArguments(NSCoder * coder), SentrySWReplacement({
            [SentryUIViewControllerSwizziling swizzleViewControllerSubClass:[self class]];
            return SentrySWCallOriginal(coder);
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, swizzleViewControllerInitWithCoder);

    static const void *swizzleViewControllerInitWithNib = &swizzleViewControllerInitWithNib;
    SEL nibSelector = NSSelectorFromString(@"initWithNibName:bundle:");
    SentrySwizzleInstanceMethod(UIViewController.class, nibSelector, SentrySWReturnType(id),
        SentrySWArguments(NSString * nibName, NSBundle * bundle), SentrySWReplacement({
            [SentryUIViewControllerSwizziling swizzleViewControllerSubClass:[self class]];
            return SentrySWCallOriginal(nibName, bundle);
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, swizzleViewControllerInitWithNib);

    [SentryUIViewControllerSwizziling swizzleRootViewController];
}

/**
 * If an app targets, for example, iOS 13 or lower, the UIKit inits the initial/root view controller
 * before the SentrySDK is initialized. Therefore, we manually call swizzle here not to lose
 * auto-generated transactions for the initial view controller. As we use
 * SentrySwizzleModeOncePerClassAndSuperclasses, we don't have to worry about swizzling twice. We
 * could also use objc_getClassList to lookup sub classes of UIViewController, but the lookup can
 * take around 60ms, which is not acceptable.
 */
+ (void)swizzleRootViewController
{
    if (![UIApplication respondsToSelector:@selector(sharedApplication)]) {
        [SentryLog logWithMessage:@"UIApplication doesn't respont to sharedApplication. Skipping "
                                  @"swizzleRootViewController."
                         andLevel:kSentryLevelDebug];
        return;
    }

    UIApplication *app = [UIApplication performSelector:@selector(sharedApplication)];

    if (app == nil) {
        [SentryLog logWithMessage:@"UIApplication is nil. Skipping swizzleRootViewController."
                         andLevel:kSentryLevelDebug];
        return;
    }

    if (app.delegate == nil) {
        [SentryLog
            logWithMessage:@"UIApplicationDelegate is nil. Skipping swizzleRootViewController."
                  andLevel:kSentryLevelDebug];
        return;
    }

    // Check if delegate responds to window, which it doesn't have to.
    if (![app.delegate respondsToSelector:@selector(window)]) {
        [SentryLog logWithMessage:@"UIApplicationDelegate doesn't respond to window selctor. "
                                  @"Skipping swizzleRootViewController."
                         andLevel:kSentryLevelDebug];
        return;
    }

    if (app.delegate.window == nil) {
        [SentryLog logWithMessage:
                       @"UIApplicationDelegate.window is nil. Skipping swizzleRootViewController."
                         andLevel:kSentryLevelDebug];
        return;
    }

    UIViewController *rootViewController = app.delegate.window.rootViewController;
    if (rootViewController == nil) {
        [SentryLog logWithMessage:@"UIApplicationDelegate.window.rootViewController is nil. "
                                  @"Skipping swizzleRootViewController."
                         andLevel:kSentryLevelDebug];
        return;
    }

    NSArray<UIViewController *> *allViewControllers = rootViewController.descendantViewControllers;

    for (UIViewController *viewController in allViewControllers) {
        Class viewControllerClass = [viewController class];
        if (viewControllerClass != nil) {
            [SentryLog logWithMessage:@"Calling swizzleRootViewController."
                             andLevel:kSentryLevelDebug];
            [SentryUIViewControllerSwizziling swizzleViewControllerSubClass:viewControllerClass];
        }
    }
}

+ (void)swizzleViewControllerSubClass:(Class)class
{
    // Swizzling only classes from the user app module to avoid track every UIKit view controller
    // interaction.
    static const char *appImage = nil;
    if (appImage == nil) {
        if ([UIApplication respondsToSelector:@selector(sharedApplication)]) {
            UIApplication *app = [UIApplication performSelector:@selector(sharedApplication)];
            appImage = class_getImageName(app.delegate.class);
        }
    }
    if (appImage == nil || strcmp(appImage, class_getImageName(class)) != 0)
        return;

    // This are the five main functions related to UI creation in a view controller.
    // We are swizzling it to track anything that happens inside one of this functions.
    [SentryUIViewControllerSwizziling swizzleViewLayoutSubViews:class];
    [SentryUIViewControllerSwizziling swizzleLoadView:class];
    [SentryUIViewControllerSwizziling swizzleViewDidLoad:class];
    [SentryUIViewControllerSwizziling swizzleViewWillAppear:class];
    [SentryUIViewControllerSwizziling swizzleViewDidAppear:class];
}

+ (void)swizzleLoadView:(Class)class
{
    SEL selector = NSSelectorFromString(@"loadView");
    SentrySwizzleInstanceMethod(class, selector, SentrySWReturnType(void), SentrySWArguments(),
        SentrySWReplacement({
            [SentryUIViewControllerPerformanceTracker.shared
                viewControllerLoadView:self
                      callbackToOrigin:^{ SentrySWCallOriginal(); }];
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)selector);
}

+ (void)swizzleViewDidLoad:(Class)class
{
    SEL selector = NSSelectorFromString(@"viewDidLoad");
    SentrySwizzleInstanceMethod(class, selector, SentrySWReturnType(void), SentrySWArguments(),
        SentrySWReplacement({
            [SentryUIViewControllerPerformanceTracker.shared
                viewControllerViewDidLoad:self
                         callbackToOrigin:^{ SentrySWCallOriginal(); }];
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)selector);
}

+ (void)swizzleViewWillAppear:(Class)class
{
    SEL selector = NSSelectorFromString(@"viewWillAppear:");
    SentrySwizzleInstanceMethod(class, selector, SentrySWReturnType(void),
        SentrySWArguments(BOOL animated), SentrySWReplacement({
            [SentryUIViewControllerPerformanceTracker.shared
                viewControllerViewWillAppear:self
                            callbackToOrigin:^{ SentrySWCallOriginal(animated); }];
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)selector);
}

+ (void)swizzleViewDidAppear:(Class)class
{
    SEL selector = NSSelectorFromString(@"viewDidAppear:");
    SentrySwizzleInstanceMethod(class, selector, SentrySWReturnType(void),
        SentrySWArguments(BOOL animated), SentrySWReplacement({
            [SentryUIViewControllerPerformanceTracker.shared
                viewControllerViewDidAppear:self
                           callbackToOrigin:^{ SentrySWCallOriginal(animated); }];
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)selector);
}

+ (void)swizzleViewLayoutSubViews:(Class)class
{
    SEL willSelector = NSSelectorFromString(@"viewWillLayoutSubviews");
    SentrySwizzleInstanceMethod(class, willSelector, SentrySWReturnType(void), SentrySWArguments(),
        SentrySWReplacement({
            [SentryUIViewControllerPerformanceTracker.shared
                viewControllerViewWillLayoutSubViews:self
                                    callbackToOrigin:^{ SentrySWCallOriginal(); }];
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)willSelector);

    SEL didSelector = NSSelectorFromString(@"viewDidLayoutSubviews");
    SentrySwizzleInstanceMethod(class, didSelector, SentrySWReturnType(void), SentrySWArguments(),
        SentrySWReplacement({
            [SentryUIViewControllerPerformanceTracker.shared
                viewControllerViewDidLayoutSubViews:self
                                   callbackToOrigin:^{ SentrySWCallOriginal(); }];
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)didSelector);
}

@end

#    pragma clang diagnostic pop
#endif
