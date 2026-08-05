#import "SentryUIViewControllerSwizzlingHelper.h"

#if SENTRY_HAS_UIKIT

#    import "SentryInternalDefines.h"
#    import "SentrySwift.h"
#    import "SentrySwizzle.h"
#    import <UIKit/UIKit.h>
#    import <objc/runtime.h>

@implementation SentryUIViewControllerSwizzlingHelper

static __weak SentryUIViewControllerPerformanceTracker *_tracker = nil;

// Weak, like _tracker: a strong reference here would outlive the caller that installed the funnel.
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
    SENTRY_ASSERT([NSThread isMainThread],
        @"swizzleUIViewControllerWithTracker: must be called on the main thread.");

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

/**
 * Swizzles the two base @c UIViewController designated initializers and notifies @c delegate after
 * each one, so the caller can defer its own swizzling to first instantiation.
 *
 * Every @c UIViewController is created through one of the two: a subclass's designated init calls
 * super, a convenience init routes through a designated init, and @c -init routes through
 * @c initWithNibName:bundle:.
 *
 * The initializers are swizzled only on the base class, so that part REPLACES UIKit's own
 * implementation rather than adding a method. That does not mean the funnel only mutates the base
 * class: the handler runs @c swizzleViewControllerSubClass: on the concrete subclass, and
 * @c class_replaceMethod ADDS a lifecycle method when the subclass doesn't implement one — while
 * still inside the outermost initializer frame. That is the same mechanism GH-1361 blamed for the
 * GH-1355 convenience-initializer crash, so this funnel does not eliminate the condition. We could
 * not reproduce GH-1355; see PR #8625's description for what we tried and why we shipped anyway.
 *
 * Ordering inside the replacement is load-bearing:
 *   1. Call the original initializer FIRST, and never touch @c self before it. The pre-GH-1361
 *      code messaged @c self and mutated the class before the original ran.
 *   2. Read the concrete class from the RETURNED object via @c object_getClass, a C runtime call
 *      rather than a message. This handles an init returning a different instance, or nil.
 *   3. Invoke the handler synchronously, so lifecycle methods are swizzled before the instance
 *      can reach its first @c viewDidLoad.
 *   4. Return the result verbatim, adding no retain, so ARC's return handshake stays balanced.
 *
 * Step 3 must not hop through @c dispatch_async(dispatch_get_main_queue(), …) to escape the
 * initializer frame. UIKit calls initializers on the main thread, so a dispatch from the main
 * thread cannot run until the current run loop turn finishes — by which point the caller already
 * holds a fully initialized instance and may have driven it into @c viewDidLoad, or released it.
 * That opens a window where a live view controller is uninstrumented, and it reorders the swizzle
 * against that instance's own first lifecycle callbacks, so the first appearance of a screen is
 * silently missed. Swizzling synchronously keeps the mutation ordered against the very first
 * callback. It is also why everything here is main-thread-only and unlocked: the delegate hand-off
 * happens on whichever thread ran the initializer, and moving it off-thread would race both this
 * file's static state and the ObjC runtime mutations in @c swizzleViewControllerSubClass:
 * (background swizzling already caused GH-1366).
 *
 * We use the ObjC @c SentrySwizzleInstanceMethod macro rather than the typed Swift API that
 * develop-docs/SWIZZLING.md prefers (@c SentryTypedSwizzle, #8524): its object-returning overloads
 * model +0 autoreleased returns, while an initializer returns +1, which Swift cannot express
 * through an @c \@convention(block) object return without passing @c Unmanaged across the
 * boundary. @c SentryNSDataSwizzlingHelper.m uses this same macro path for
 * @c -[NSData initWithContentsOfFile:options:error:], another +1 initializer. The retain
 * handshake is covered by @c testInitFunnel_whenViewControllersInstantiated_doesNotOverRetainThem.
 *
 * @warning Experimental and opt-in, disabled by default. See GH-8548.
 */
+ (void)swizzleUIViewControllerInitsWithDelegate:
    (id<SentryUIViewControllerInitSwizzlingDelegate>)delegate
{
    SENTRY_ASSERT([NSThread isMainThread],
        @"swizzleUIViewControllerInitsWithDelegate: must be called on the main thread.");

    _initSwizzlingDelegate = delegate;

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
    SENTRY_ASSERT([NSThread isMainThread],
        @"swizzleViewControllerSubClass: must be called on the main thread.");

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
    SENTRY_ASSERT([NSThread isMainThread], @"stop must be called on the main thread.");

    _tracker = nil;
    _initSwizzlingDelegate = nil;
#    if SENTRY_TEST || SENTRY_TEST_CI
    [self unswizzle];
#    endif
}

#    if SENTRY_TEST || SENTRY_TEST_CI
+ (void)unswizzle
{
    SENTRY_ASSERT([NSThread isMainThread], @"unswizzle must be called on the main thread.");

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
