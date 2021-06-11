#import "SentryUISwizziling.h"
#import "SentryHub.h"
#import "SentryLog.h"
#import "SentryPerformanceTracker.h"
#import "SentrySDK+Private.h"
#import "SentryScope.h"
#import "SentrySpanId.h"
#import "SentrySwizzle.h"
#import "SentryUIPerformanceTracker.h"
#import "SentryUIViewControllerSanitizer.h"
#import <objc/runtime.h>

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>

@implementation SentryUISwizziling

+ (void)start
{
    [SentryUISwizziling swizzleViewControllerInits];
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
            [SentryUISwizziling swizzleViewControllerSubClass:[self class]];
            return SentrySWCallOriginal(coder);
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, swizzleViewControllerInitWithCoder);

    static const void *swizzleViewControllerInitWithNib = &swizzleViewControllerInitWithNib;
    SEL nibSelector = NSSelectorFromString(@"initWithNibName:bundle:");
    SentrySwizzleInstanceMethod(UIViewController.class, nibSelector, SentrySWReturnType(id),
        SentrySWArguments(NSString * nibName, NSBundle * bundle), SentrySWReplacement({
            [SentryUISwizziling swizzleViewControllerSubClass:[self class]];
            return SentrySWCallOriginal(nibName, bundle);
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, swizzleViewControllerInitWithNib);
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
    [SentryUISwizziling swizzleViewLayoutSubViews:class];
    [SentryUISwizziling swizzleLoadView:class];
    [SentryUISwizziling swizzleViewDidLoad:class];
    [SentryUISwizziling swizzleViewWillAppear:class];
    [SentryUISwizziling swizzleViewDidAppear:class];
}

+ (void)swizzleLoadView:(Class)class
{
    SEL selector = NSSelectorFromString(@"loadView");
    SentrySwizzleInstanceMethod(class, selector, SentrySWReturnType(void), SentrySWArguments(),
        SentrySWReplacement({
            [SentryUIPerformanceTracker.shared viewControllerLoadView:self
                                                     callbackToOrigin:^{ SentrySWCallOriginal(); }];
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)selector);
}

+ (void)swizzleViewDidLoad:(Class)class
{
    SEL selector = NSSelectorFromString(@"viewDidLoad");
    SentrySwizzleInstanceMethod(class, selector, SentrySWReturnType(void), SentrySWArguments(),
        SentrySWReplacement({
            [SentryUIPerformanceTracker.shared
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
            [SentryUIPerformanceTracker.shared
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
            [SentryUIPerformanceTracker.shared
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
            [SentryUIPerformanceTracker.shared
                viewControllerViewWillLayoutSubViews:self
                                    callbackToOrigin:^{ SentrySWCallOriginal(); }];
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)willSelector);

    SEL didSelector = NSSelectorFromString(@"viewDidLayoutSubviews");
    SentrySwizzleInstanceMethod(class, didSelector, SentrySWReturnType(void), SentrySWArguments(),
        SentrySWReplacement({
            [SentryUIPerformanceTracker.shared
                viewControllerViewDidLayoutSubViews:self
                                   callbackToOrigin:^{ SentrySWCallOriginal(); }];
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)didSelector);
}

@end

#    pragma clang diagnostic pop
#endif
