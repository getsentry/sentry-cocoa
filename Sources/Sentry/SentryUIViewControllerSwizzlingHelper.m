#import "SentryUIViewControllerSwizzlingHelper.h"

#if SENTRY_HAS_UIKIT

#    import "SentrySwift.h"
#    import "SentrySwizzle.h"
#    import <UIKit/UIKit.h>
#    import <objc/runtime.h>

@implementation SentryUIViewControllerSwizzlingHelper

static __weak SentryUIViewControllerPerformanceTracker *_tracker = nil;

// Handler invoked with the concrete class of every initialized UIViewController when the base-init
// funnel is installed. Retained (copied) for the lifetime of the funnel; cleared in +stop.
static void (^_subclassSwizzleHandler)(Class) = nil;

// File-scope swizzle keys for the two base UIViewController initializers, so +unswizzle can restore
// them with the same key used to install them.
static const void *sentryInitWithNibNameKey = &sentryInitWithNibNameKey;
static const void *sentryInitWithCoderKey = &sentryInitWithCoderKey;

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

+ (void)swizzleUIViewControllerInitsWithSubclassHandler:(void (^)(Class))handler
{
    _subclassSwizzleHandler = [handler copy];

    // Swizzle the two base UIViewController designated initializers. Every UIViewController is
    // created through one of them (a subclass's designated init calls super, which reaches one of
    // these; convenience inits route through a designated init; `-init` routes through
    // initWithNibName:bundle:). We swizzle only the BASE class, so class_replaceMethod REPLACES the
    // existing UIKit implementation rather than ADDING a method to a subclass that doesn't
    // implement it — the latter was the cause of the GH-1355 convenience-initializer crash that led
    // to removing init swizzling in GH-1361. See GH-8548 for why we bring it back (behind an
    // opt-in).
    //
    // Ordering inside the replacement is load-bearing:
    //   1. Call the original initializer FIRST. Never message or introspect `self` before it — the
    //      GH-1355 crash came from mutating the class from inside the init before the original ran.
    //   2. Read the concrete class from the RETURNED object via object_getClass (a C runtime call,
    //      not an Objective-C message). This handles init-family self-replacement (an init may
    //      return a different instance) and a nil return.
    //   3. Invoke the handler SYNCHRONOUSLY, so the instance's lifecycle methods are swizzled
    //      immediately after it is initialized — no dispatch hop that could race its first
    //      viewDidLoad. GH-1355 is avoided by the ordering above, not by leaving the init frame.
    //   4. Return the original result verbatim. The initializer's +1/autoreleased return is
    //      forwarded unchanged; we add no retain, so ARC's return handshake stays balanced. This is
    //      the same block-based pass-through shape SentryNSDataSwizzlingHelper.m uses for
    //      initWithContentsOfFile:options:error:.
    //
    // NOTE: we deliberately use the ObjC SentrySwizzleInstanceMethod macro here rather than the
    // typed Swift swizzle API (SentryTypedSwizzle, added in #8524). That API's only
    // object-returning overloads model +0 autoreleased returns (URLSessionDataTask); an initializer
    // returns +1 (ns_returns_retained), which the typed API does not support. This macro path is
    // the audited mechanism already used for NSData's init swizzle. See develop-docs/SWIZZLING.md
    // and GH-8548.
    SEL nibSelector = NSSelectorFromString(@"initWithNibName:bundle:");
    SentrySwizzleInstanceMethod(UIViewController.class, nibSelector, SentrySWReturnType(id),
        SentrySWArguments(NSString * nibName, NSBundle * bundle), SentrySWReplacement({
            id result = SentrySWCallOriginal(nibName, bundle);
            void (^subclassHandler)(Class) = _subclassSwizzleHandler;
            if (result != nil && subclassHandler != nil) {
                subclassHandler(object_getClass(result));
            }
            return result;
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)sentryInitWithNibNameKey);

    SEL coderSelector = NSSelectorFromString(@"initWithCoder:");
    SentrySwizzleInstanceMethod(UIViewController.class, coderSelector, SentrySWReturnType(id),
        SentrySWArguments(NSCoder * coder), SentrySWReplacement({
            id result = SentrySWCallOriginal(coder);
            void (^subclassHandler)(Class) = _subclassSwizzleHandler;
            if (result != nil && subclassHandler != nil) {
                subclassHandler(object_getClass(result));
            }
            return result;
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)sentryInitWithCoderKey);
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
    // Clearing the handler makes the base-init funnel replacements pure pass-throughs (call
    // original, return) — the same no-op-when-nil pattern the lifecycle swizzles use with _tracker.
    _subclassSwizzleHandler = nil;
#    if SENTRY_TEST || SENTRY_TEST_CI
    [self unswizzle];
#    endif
}

#    if SENTRY_TEST || SENTRY_TEST_CI
+ (void)unswizzle
{
    swizzlingIsActive = FALSE;

    // Unswizzling is only supported in test targets as it is considered unsafe for production.
    // Only unswizzle the base UIViewController methods we swizzle on the base class itself:
    // loadView and the two designated initializers (the init funnel). Other lifecycle methods are
    // swizzled per-subclass and we don't track which subclasses were swizzled, so we can't safely
    // unswizzle them. The stop method sets _tracker = nil and _subclassSwizzleHandler = nil, which
    // makes all swizzled methods no-ops anyway.
    SEL loadViewSelector = NSSelectorFromString(@"loadView");
    SentryUnswizzleInstanceMethod(
        UIViewController.class, loadViewSelector, (void *)loadViewSelector);

    SentryUnswizzleInstanceMethod(UIViewController.class,
        NSSelectorFromString(@"initWithNibName:bundle:"), (void *)sentryInitWithNibNameKey);
    SentryUnswizzleInstanceMethod(UIViewController.class, NSSelectorFromString(@"initWithCoder:"),
        (void *)sentryInitWithCoderKey);
}

+ (BOOL)swizzlingActive
{
    return swizzlingIsActive;
}
#    endif

#    pragma clang diagnostic pop

@end

#endif // SENTRY_HAS_UIKIT
