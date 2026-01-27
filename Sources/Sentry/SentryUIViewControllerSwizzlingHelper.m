#import "SentryUIViewControllerSwizzlingHelper.h"

#if SENTRY_HAS_UIKIT

#    import "SentrySwift.h"
#    import "SentrySwizzle.h"
#    import <UIKit/UIKit.h>
#    import <objc/runtime.h>

@implementation SentryUIViewControllerSwizzlingHelper

static __weak SentryUIViewControllerPerformanceTracker *_tracker = nil;
#    if SENTRY_TEST || SENTRY_TEST_CI
static BOOL swizzlingIsActive = FALSE;
#    endif

// SentrySwizzleInstanceMethod declaration shadows a local variable. The swizzling is working
// fine and we accept this warning.
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wshadow"

+ (void)swizzleUIViewControllerWithTracker:(SentryUIViewControllerPerformanceTracker *)tracker
{
    _tracker = tracker;
#    if SENTRY_TEST || SENTRY_TEST_CI
    swizzlingIsActive = TRUE;
#    endif

    SEL selector = NSSelectorFromString(@"loadView");
    SentrySwizzleInstanceMethod(UIViewController.class, selector, SentrySWReturnType(void),
        SentrySWArguments(), SentrySWReplacement({
            SentryUIViewControllerPerformanceTracker *tracker = _tracker;
            if (tracker != nil) {
                [tracker viewControllerLoadView:self callbackToOrigin:^{ SentrySWCallOriginal(); }];
            } else {
                SentrySWCallOriginal();
            }
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)selector);
}

+ (void)swizzleViewControllerSubClass:(Class)class
{
    // This are the five main functions related to UI creation in a view controller.
    // We are swizzling it to track anything that happens inside one of this functions.
    [self swizzleViewLayoutSubViews:class];
    [self swizzleLoadView:class];
    [self swizzleViewDidLoad:class];
    [self swizzleViewWillAppear:class];
    [self swizzleViewWillDisappear:class];
    [self swizzleViewDidAppear:class];
}

+ (void)swizzleLoadView:(Class)class
{
    // Loading a Nib file is done automatically during `loadView` in the UIViewController
    // or other native view controllers.
    // When swizzling the loadView of a custom UIViewController, the UIViewController doesn't search
    // for a nib file and doesn't load a view. This would lead to crashes as no view is loaded.
    // By checking the implementation pointer of `loadView` from the current class with
    // the implementation pointer of its parent class, we can determine if current class
    // has a custom implementation of it, therefore it's safe to swizzle it.
    SEL selector = NSSelectorFromString(@"loadView");
    IMP viewControllerImp = class_getMethodImplementation([class superclass], selector);
    IMP classLoadViewImp = class_getMethodImplementation(class, selector);
    if (viewControllerImp == classLoadViewImp) {
        return;
    }

    SentrySwizzleInstanceMethod(class, selector, SentrySWReturnType(void), SentrySWArguments(),
        SentrySWReplacement({
            SentryUIViewControllerPerformanceTracker *tracker = _tracker;
            if (tracker != nil) {
                [tracker viewControllerLoadView:self callbackToOrigin:^{ SentrySWCallOriginal(); }];
            } else {
                SentrySWCallOriginal();
            }
        }),
        SentrySwizzleModeOncePerClass, (void *)selector);
}

+ (void)swizzleViewDidLoad:(Class)class
{
    SEL selector = NSSelectorFromString(@"viewDidLoad");
    SentrySwizzleInstanceMethod(class, selector, SentrySWReturnType(void), SentrySWArguments(),
        SentrySWReplacement({
            SentryUIViewControllerPerformanceTracker *tracker = _tracker;
            if (tracker != nil) {
                [tracker viewControllerViewDidLoad:self
                                  callbackToOrigin:^{ SentrySWCallOriginal(); }];
            } else {
                SentrySWCallOriginal();
            }
        }),
        SentrySwizzleModeOncePerClass, (void *)selector);
}

+ (void)swizzleViewWillAppear:(Class)class
{
    SEL selector = NSSelectorFromString(@"viewWillAppear:");
    SentrySwizzleInstanceMethod(class, selector, SentrySWReturnType(void),
        SentrySWArguments(BOOL animated), SentrySWReplacement({
            SentryUIViewControllerPerformanceTracker *tracker = _tracker;
            if (tracker != nil) {
                [tracker viewControllerViewWillAppear:self
                                     callbackToOrigin:^{ SentrySWCallOriginal(animated); }];
            } else {
                SentrySWCallOriginal(animated);
            }
        }),
        SentrySwizzleModeOncePerClass, (void *)selector);
}

+ (void)swizzleViewDidAppear:(Class)class
{
    SEL selector = NSSelectorFromString(@"viewDidAppear:");
    SentrySwizzleInstanceMethod(class, selector, SentrySWReturnType(void),
        SentrySWArguments(BOOL animated), SentrySWReplacement({
            SentryUIViewControllerPerformanceTracker *tracker = _tracker;
            if (tracker != nil) {
                [tracker viewControllerViewDidAppear:self
                                    callbackToOrigin:^{ SentrySWCallOriginal(animated); }];
            } else {
                SentrySWCallOriginal(animated);
            }
        }),
        SentrySwizzleModeOncePerClass, (void *)selector);
}

+ (void)swizzleViewWillDisappear:(Class)class
{
    SEL selector = NSSelectorFromString(@"viewWillDisappear:");
    SentrySwizzleInstanceMethod(class, selector, SentrySWReturnType(void),
        SentrySWArguments(BOOL animated), SentrySWReplacement({
            SentryUIViewControllerPerformanceTracker *tracker = _tracker;
            if (tracker != nil) {
                [tracker viewControllerViewWillDisappear:self
                                        callbackToOrigin:^{ SentrySWCallOriginal(animated); }];
            } else {
                SentrySWCallOriginal(animated);
            }
        }),
        SentrySwizzleModeOncePerClass, (void *)selector);
}

+ (void)swizzleViewLayoutSubViews:(Class)class
{
    SEL willSelector = NSSelectorFromString(@"viewWillLayoutSubviews");
    SentrySwizzleInstanceMethod(class, willSelector, SentrySWReturnType(void), SentrySWArguments(),
        SentrySWReplacement({
            SentryUIViewControllerPerformanceTracker *tracker = _tracker;
            if (tracker != nil) {
                [tracker viewControllerViewWillLayoutSubViews:self
                                             callbackToOrigin:^{ SentrySWCallOriginal(); }];
            } else {
                SentrySWCallOriginal();
            }
        }),
        SentrySwizzleModeOncePerClass, (void *)willSelector);

    SEL didSelector = NSSelectorFromString(@"viewDidLayoutSubviews");
    SentrySwizzleInstanceMethod(class, didSelector, SentrySWReturnType(void), SentrySWArguments(),
        SentrySWReplacement({
            SentryUIViewControllerPerformanceTracker *tracker = _tracker;
            if (tracker != nil) {
                [tracker viewControllerViewDidLayoutSubViews:self
                                            callbackToOrigin:^{ SentrySWCallOriginal(); }];
            } else {
                SentrySWCallOriginal();
            }
        }),
        SentrySwizzleModeOncePerClass, (void *)didSelector);
}

+ (void)stop
{
    _tracker = nil;
#    if SENTRY_TEST || SENTRY_TEST_CI
    [self unswizzle];
#    endif
}

#    if SENTRY_TEST || SENTRY_TEST_CI
+ (void)unswizzle
{
    swizzlingIsActive = FALSE;

    // Unswizzling is only supported in test targets as it is considered unsafe for production.
    // Only unswizzle the base UIViewController.loadView since that's the only method swizzled
    // on the base class. Other lifecycle methods are swizzled per-subclass and we don't track
    // which subclasses were swizzled, so we can't safely unswizzle them.
    // The stop method sets _tracker = nil which makes all swizzled methods no-ops anyway.
    SEL loadViewSelector = NSSelectorFromString(@"loadView");
    SentryUnswizzleInstanceMethod(
        UIViewController.class, loadViewSelector, (void *)loadViewSelector);
}

+ (BOOL)swizzlingActive
{
    return swizzlingIsActive;
}
#    endif

#    pragma clang diagnostic pop

@end

#endif // SENTRY_HAS_UIKIT
