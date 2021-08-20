#import "SentryUIViewControllerSwizziling.h"
#import "SentryLog.h"
#import "SentryPerformanceTracker.h"
#import "SentrySwizzle.h"
#import "SentryUIViewControllerPerformanceTracker.h"
#import <SentryInAppLogic.h>
#import <SentryOptions.h>
#import <UIViewController+Sentry.h>
#import <objc/runtime.h>

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>

@implementation SentryUIViewControllerSwizziling

static SentryInAppLogic *inAppLogic;

+ (void)startWithOptions:(SentryOptions *)options
{
    inAppLogic = [[SentryInAppLogic alloc] initWithInAppIncludes:options.inAppIncludes
                                                   inAppExcludes:options.inAppExcludes];
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
            [SentryUIViewControllerSwizziling swizzleViewControllerSubClass:[self class] isNib:NO];
            return SentrySWCallOriginal(coder);
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, swizzleViewControllerInitWithCoder);

    static const void *swizzleViewControllerInitWithNib = &swizzleViewControllerInitWithNib;
    SEL nibSelector = NSSelectorFromString(@"initWithNibName:bundle:");
    SentrySwizzleInstanceMethod(UIViewController.class, nibSelector, SentrySWReturnType(id),
        SentrySWArguments(NSString * nibName, NSBundle * bundle), SentrySWReplacement({
            [SentryUIViewControllerSwizziling swizzleViewControllerSubClass:[self class] isNib:YES];
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
        NSString *message = @"UIViewControllerSwizziling: UIApplication doesn't respont to "
                            @"sharedApplication. Skipping swizzleRootViewController.";
        [SentryLog logWithMessage:message andLevel:kSentryLevelDebug];
        return;
    }

    UIApplication *app = [UIApplication performSelector:@selector(sharedApplication)];

    if (app == nil) {
        NSString *message = @"UIViewControllerSwizziling: UIApplication is nil. Skipping "
                            @"swizzleRootViewController.";
        [SentryLog logWithMessage:message andLevel:kSentryLevelDebug];
        return;
    }

    if (app.delegate == nil) {
        NSString *message = @"UIViewControllerSwizziling: UIApplicationDelegate is nil. Skipping "
                            @"swizzleRootViewController.";
        [SentryLog logWithMessage:message andLevel:kSentryLevelDebug];
        return;
    }

    // Check if delegate responds to window, which it doesn't have to.
    if (![app.delegate respondsToSelector:@selector(window)]) {
        NSString *message
            = @"UIApplicationDelegate.window is nil. Skipping swizzleRootViewController.";
        [SentryLog logWithMessage:message andLevel:kSentryLevelDebug];
        return;
    }

    if (app.delegate.window == nil) {
        NSString *message = @"UIViewControllerSwizziling UIApplicationDelegate.window is nil. "
                            @"Skipping swizzleRootViewController.";
        [SentryLog logWithMessage:message andLevel:kSentryLevelDebug];
        return;
    }

    UIViewController *rootViewController = app.delegate.window.rootViewController;
    if (rootViewController == nil) {
        NSString *message
            = @"UIViewControllerSwizziling UIApplicationDelegate.window.rootViewController is nil. "
              @"Skipping swizzleRootViewController.";
        [SentryLog logWithMessage:message andLevel:kSentryLevelDebug];
        return;
    }

    NSArray<UIViewController *> *allViewControllers = rootViewController.descendantViewControllers;

    for (UIViewController *viewController in allViewControllers) {
        Class viewControllerClass = [viewController class];
        if (viewControllerClass != nil) {
            NSString *message = @"UIViewControllerSwizziling Calling swizzleRootViewController.";
            [SentryLog logWithMessage:message andLevel:kSentryLevelDebug];

            // We don't now if it the UIViewController uses a nib or not.
            [SentryUIViewControllerSwizziling swizzleViewControllerSubClass:viewControllerClass
                                                                      isNib:YES];
        }
    }
}

+ (void)swizzleViewControllerSubClass:(Class)class isNib:(BOOL)isNib
{
    if (![SentryUIViewControllerSwizziling shouldSwizzleViewController:class])
        return;

    // This are the five main functions related to UI creation in a view controller.
    // We are swizzling it to track anything that happens inside one of this functions.
    [SentryUIViewControllerSwizziling swizzleViewLayoutSubViews:class];
    [SentryUIViewControllerSwizziling swizzleLoadView:class isNib:isNib];
    [SentryUIViewControllerSwizziling swizzleViewDidLoad:class];
    [SentryUIViewControllerSwizziling swizzleViewWillAppear:class];
    [SentryUIViewControllerSwizziling swizzleViewDidAppear:class];
}

/**
 * For testing.
 */
+ (BOOL)shouldSwizzleViewController:(Class)class
{
    // Swizzling only inApp classes to avoid track every UIKit view controller
    // interaction.
    NSString *classImageName = [NSString stringWithCString:class_getImageName(class)
                                                  encoding:NSUTF8StringEncoding];
    return [inAppLogic isInApp:classImageName];
}

+ (void)swizzleLoadView:(Class)class isNib:(BOOL)isNib
{
    // The UIViewController only searches for a nib file if you do not override the loadView method.
    // When swizzling the loadView of a custom UIViewController, the UIViewController doesn't search
    // for a nib file and doesn't load a view. This would lead to crashes as no view is loaded. As a
    // workaround, we skip swizzling the loadView and accept that the SKD doesn't create a span for
    // loadView if the UIViewController doesn't implement it.
    if (isNib) {
        return;
    }

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
