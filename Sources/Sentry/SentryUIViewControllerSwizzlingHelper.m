#import "SentryUIViewControllerSwizzlingHelper.h"

#if SENTRY_HAS_UIKIT

#    import "SentrySwift.h"
#    import "SentrySwizzle.h"
#    import <UIKit/UIKit.h>
#    import <objc/runtime.h>

@implementation SentryUIViewControllerSwizzlingHelper

static __weak SentryUIViewControllerPerformanceTracker *_tracker = nil;

// Weak, like _tracker: the delegate is the caller that installed the funnel, and a strong reference
// here would outlive it for the process lifetime.
static __weak id<SentryUIViewControllerInitSwizzlingDelegate> _initSwizzlingDelegate = nil;

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

+ (void)swizzleUIViewControllerInitsWithDelegate:
    (id<SentryUIViewControllerInitSwizzlingDelegate>)delegate
{
    _initSwizzlingDelegate = delegate;

    // EXPERIMENTAL: only installed when options.experimental.enableUIViewControllerInitSwizzling is
    // enabled. Disabled by default.
    //
    // Swizzle the two base UIViewController designated initializers. Every UIViewController is
    // created through one of them: a subclass's designated init calls super, convenience inits
    // route through a designated init, and `-init` routes through initWithNibName:bundle:.
    //
    // The INITIALIZERS are swizzled only on the base class, so that part replaces UIKit's own
    // implementation rather than adding a method. Note this does NOT mean the funnel only ever
    // mutates the base class: the handler runs swizzleViewControllerSubClass: on the concrete
    // subclass, and class_replaceMethod ADDS a lifecycle method when the subclass doesn't implement
    // it. That happens while still inside the outermost initializer frame, which is the same
    // mechanism GH-1361 blamed for the GH-1355 convenience-initializer crash.
    //
    // We could not demonstrate that as a crasher: a standalone probe reproducing the pre-GH-1361
    // ordering, and confirming it ADDED all lifecycle methods to a Swift UITableViewController
    // subclass mid-init, stayed crash-free on iOS 15.5, 18.6 and 26.4 across the reported shapes
    // (convenience init, navigation push, second instance, UIPageViewController). GH-1355 was only
    // ever seen on iOS 15.0 in Release/TestFlight builds, was reproduced by a maintainer in an
    // empty project with no SDK attached (https://developer.apple.com/forums/thread/691371), and
    // iOS 15.0 cannot be installed on current macOS hosts. Best reading: an iOS-15.0-era UIKit bug
    // that swizzling perturbed. This funnel is experimental and opt-in partly for that reason.
    //
    // Ordering inside the replacement is load-bearing:
    //   1. Call the original initializer FIRST, and never touch `self` before it. The pre-GH-1361
    //      code messaged `self` and mutated the class before the original ran.
    //   2. Read the concrete class from the RETURNED object via object_getClass, a C runtime call
    //      rather than a message. This handles an init returning a different instance, or nil.
    //   3. Invoke the handler synchronously, so lifecycle methods are swizzled before the instance
    //      can reach its first viewDidLoad.
    //   4. Return the result verbatim, adding no retain, so ARC's return handshake stays balanced.
    //
    // We use the ObjC SentrySwizzleInstanceMethod macro rather than the typed Swift API that
    // develop-docs/SWIZZLING.md prefers (SentryTypedSwizzle, #8524): its object-returning overloads
    // model +0 autoreleased returns, while an initializer returns +1, which Swift cannot express
    // through an @convention(block) object return without passing Unmanaged across the boundary.
    // SentryNSDataSwizzlingHelper.m uses this same macro path for -[NSData
    // initWithContentsOfFile:options:error:], another +1 initializer. The retain handshake is
    // covered by testInitFunnel_whenViewControllersInstantiated_doesNotOverRetainThem.
    SEL nibSelector = NSSelectorFromString(@"initWithNibName:bundle:");
    SentrySwizzleInstanceMethod(UIViewController.class, nibSelector, SentrySWReturnType(id),
        SentrySWArguments(NSString * nibName, NSBundle * bundle), SentrySWReplacement({
            id<SentryUIViewControllerInitSwizzlingDelegate> delegate = _initSwizzlingDelegate;
            id result = SentrySWCallOriginal(nibName, bundle);
            Class resultClass = object_getClass(result);
            if (resultClass != Nil) {
                [delegate viewControllerInitialized:resultClass];
            }
            return result;
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)nibSelector);

    SEL coderSelector = NSSelectorFromString(@"initWithCoder:");
    SentrySwizzleInstanceMethod(UIViewController.class, coderSelector, SentrySWReturnType(id),
        SentrySWArguments(NSCoder * coder), SentrySWReplacement({
            id<SentryUIViewControllerInitSwizzlingDelegate> delegate = _initSwizzlingDelegate;
            id result = SentrySWCallOriginal(coder);
            Class resultClass = object_getClass(result);
            if (resultClass != Nil) {
                [delegate viewControllerInitialized:resultClass];
            }
            return result;
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)coderSelector);
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
    // Clearing the delegate makes the base-init funnel replacements pure pass-throughs (call
    // original, return) — the same no-op-when-nil pattern the lifecycle swizzles use with _tracker.
    _initSwizzlingDelegate = nil;
#    if SENTRY_TEST || SENTRY_TEST_CI
    [self unswizzle];
#    endif
}

#    if SENTRY_TEST || SENTRY_TEST_CI
+ (void)unswizzle
{
    swizzlingIsActive = FALSE;

    // Unswizzling is only supported in test targets as it is considered unsafe for production.
    // Restores everything swizzled on the base UIViewController: loadView and the two init funnel
    // initializers. Leaving the funnel installed would leak it into every later test suite in the
    // same run, because a live base-class IMP outlives the handler that stop clears. Lifecycle
    // methods are swizzled per-subclass and we don't track which subclasses were swizzled, but
    // those are harmless because stop sets _tracker to nil, making them pass-throughs.
    SEL loadViewSelector = NSSelectorFromString(@"loadView");
    SentryUnswizzleInstanceMethod(
        UIViewController.class, loadViewSelector, (void *)loadViewSelector);

    SEL nibSelector = NSSelectorFromString(@"initWithNibName:bundle:");
    SentryUnswizzleInstanceMethod(UIViewController.class, nibSelector, (void *)nibSelector);

    SEL coderSelector = NSSelectorFromString(@"initWithCoder:");
    SentryUnswizzleInstanceMethod(UIViewController.class, coderSelector, (void *)coderSelector);
}

+ (BOOL)swizzlingActive
{
    return swizzlingIsActive;
}
#    endif

#    pragma clang diagnostic pop

@end

#endif // SENTRY_HAS_UIKIT
