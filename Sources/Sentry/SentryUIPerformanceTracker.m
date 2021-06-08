#import "SentryUIPerformanceTracker.h"
#import "SentryHub.h"
#import "SentryLog.h"
#import "SentryPerformanceTracker.h"
#import "SentrySDK+Private.h"
#import "SentryScope.h"
#import "SentrySpanId.h"
#import "SentrySwizzle.h"
#import "SentryUIViewControllerSanitizer.h"
#import <objc/runtime.h>

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>
#endif

static NSString *const SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID
    = @"SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID";

static NSString *const SENTRY_UI_PERFORMANCE_TRACKER_LAYOUTSUBVIEW_SPAN_ID
    = @"SENTRY_UI_PERFORMANCE_TRACKER_LAYOUTSUBVIEW_SPAN_ID";

@implementation SentryUIPerformanceTracker

+ (void)start
{
    // If there`s no UIKIT don`t need to try the swizzling.
#if SENTRY_HAS_UIKIT
    [SentryUIPerformanceTracker swizzleViewControllerInits];
#else
    [SentryLog logWithMessage:@"NO UIKit -> [SentryUIPerformanceTracker "
                              @"start] does nothing."
                     andLevel:kSentryLevelDebug];
#endif
}

// Every swizzle is used in UIKit classes.
#if SENTRY_HAS_UIKIT
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
            [SentryUIPerformanceTracker swizzleViewControllerSubClass:[self class]];
            return SentrySWCallOriginal(coder);
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, swizzleViewControllerInitWithCoder);

    static const void *swizzleViewControllerInitWithNib = &swizzleViewControllerInitWithNib;
    SEL nibSelector = NSSelectorFromString(@"initWithNibName:bundle:");
    SentrySwizzleInstanceMethod(UIViewController.class, nibSelector, SentrySWReturnType(id),
        SentrySWArguments(NSString * nibName, NSBundle * bundle), SentrySWReplacement({
            [SentryUIPerformanceTracker swizzleViewControllerSubClass:[self class]];
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
    [SentryUIPerformanceTracker swizzleViewLayoutSubViews:class];
    [SentryUIPerformanceTracker swizzleLoadView:class];
    [SentryUIPerformanceTracker swizzleViewDidLoad:class];
    [SentryUIPerformanceTracker swizzleViewWillAppear:class];
    [SentryUIPerformanceTracker swizzleViewDidAppear:class];
}

+ (void)swizzleLoadView:(Class)class
{
    SEL selector = NSSelectorFromString(@"loadView");
    SentrySwizzleInstanceMethod(class, selector, SentrySWReturnType(void), SentrySWArguments(),
        SentrySWReplacement({
            NSString *name = [SentryUIViewControllerSanitizer sanitizeViewControllerName:self];
            SentrySpanId *spanId = [SentryPerformanceTracker.shared
                startSpanWithName:name
                        operation:SENTRY_VIEWCONTROLLER_RENDERING_OPERATION];

            // use the viewcontroller itself to store the spanId to avoid using a global mapper.
            objc_setAssociatedObject(self, &SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID, spanId,
                OBJC_ASSOCIATION_RETAIN_NONATOMIC);

            [SentryPerformanceTracker.shared pushActiveSpan:spanId];
            [SentryPerformanceTracker.shared
                measureSpanWithDescription:@"loadView"
                                 operation:SENTRY_VIEWCONTROLLER_RENDERING_OPERATION
                                   inBlock:^{ SentrySWCallOriginal(); }];
            [SentryPerformanceTracker.shared popActiveSpan];
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)selector);
}

+ (void)swizzleViewDidLoad:(Class)class
{
    SEL selector = NSSelectorFromString(@"viewDidLoad");
    SentrySwizzleInstanceMethod(class, selector, SentrySWReturnType(void), SentrySWArguments(),
        SentrySWReplacement({
            SentrySpanId *spanId
                = objc_getAssociatedObject(self, &SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID);

            if (spanId == nil) {
                SentrySWCallOriginal();
            } else {
                [SentryPerformanceTracker.shared pushActiveSpan:spanId];
                [SentryPerformanceTracker.shared
                    measureSpanWithDescription:@"viewDidLoad"
                                     operation:SENTRY_VIEWCONTROLLER_RENDERING_OPERATION
                                       inBlock:^{ SentrySWCallOriginal(); }];
                [SentryPerformanceTracker.shared popActiveSpan];
            }
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)selector);
}

+ (void)swizzleViewWillAppear:(Class)class
{
    SEL selector = NSSelectorFromString(@"viewWillAppear:");
    SentrySwizzleInstanceMethod(class, selector, SentrySWReturnType(void),
        SentrySWArguments(BOOL animated), SentrySWReplacement({
            SentrySpanId *spanId
                = objc_getAssociatedObject(self, &SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID);

            if (spanId == nil) {
                SentrySWCallOriginal(animated);
            } else {
                [SentryPerformanceTracker.shared pushActiveSpan:spanId];
                [SentryPerformanceTracker.shared
                    measureSpanWithDescription:@"viewWillAppear"
                                     operation:SENTRY_VIEWCONTROLLER_RENDERING_OPERATION
                                       inBlock:^{ SentrySWCallOriginal(animated); }];
                [SentryPerformanceTracker.shared popActiveSpan];
            }
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)selector);
}

+ (void)swizzleViewDidAppear:(Class)class
{
    SEL selector = NSSelectorFromString(@"viewDidAppear:");
    SentrySwizzleInstanceMethod(class, selector, SentrySWReturnType(void),
        SentrySWArguments(BOOL animated), SentrySWReplacement({
            SentrySpanId *spanId
                = objc_getAssociatedObject(self, &SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID);

            if (spanId == nil) {
                SentrySWCallOriginal(animated);
            } else {
                [SentryPerformanceTracker.shared pushActiveSpan:spanId];
                [SentryPerformanceTracker.shared
                    measureSpanWithDescription:@"viewDidAppear"
                                     operation:SENTRY_VIEWCONTROLLER_RENDERING_OPERATION
                                       inBlock:^{ SentrySWCallOriginal(animated); }];
                [SentryPerformanceTracker.shared popActiveSpan];
                [SentryPerformanceTracker.shared finishSpan:spanId];
            }
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)selector);
}

+ (void)swizzleViewLayoutSubViews:(Class)class
{
    SEL willSelector = NSSelectorFromString(@"viewWillLayoutSubviews");
    SentrySwizzleInstanceMethod(class, willSelector, SentrySWReturnType(void), SentrySWArguments(),
        SentrySWReplacement({
            SentrySpanId *spanId
                = objc_getAssociatedObject(self, &SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID);

            if (spanId == nil || ![SentryPerformanceTracker.shared isSpanAlive:spanId]) {
                SentrySWCallOriginal();
            } else {
                [SentryPerformanceTracker.shared pushActiveSpan:spanId];
                [SentryPerformanceTracker.shared
                    measureSpanWithDescription:@"viewWillLayoutSubviews"
                                     operation:SENTRY_VIEWCONTROLLER_RENDERING_OPERATION
                                       inBlock:^{ SentrySWCallOriginal(); }];

                SentrySpanId *layoutSubViewId = [SentryPerformanceTracker.shared
                    startSpanWithName:@"layoutSubViews"
                            operation:SENTRY_VIEWCONTROLLER_RENDERING_OPERATION];

                objc_setAssociatedObject(self, &SENTRY_UI_PERFORMANCE_TRACKER_LAYOUTSUBVIEW_SPAN_ID,
                    layoutSubViewId, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

                [SentryPerformanceTracker.shared pushActiveSpan:layoutSubViewId];
            }
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)willSelector);

    SEL didSelector = NSSelectorFromString(@"viewDidLayoutSubviews");
    SentrySwizzleInstanceMethod(class, didSelector, SentrySWReturnType(void), SentrySWArguments(),
        SentrySWReplacement({
            SentrySpanId *spanId
                = objc_getAssociatedObject(self, &SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID);

            if (spanId == nil || ![SentryPerformanceTracker.shared isSpanAlive:spanId]) {
                SentrySWCallOriginal();
            } else {
                SentrySpanId *layoutSubViewId = objc_getAssociatedObject(
                    self, &SENTRY_UI_PERFORMANCE_TRACKER_LAYOUTSUBVIEW_SPAN_ID);
                [SentryPerformanceTracker.shared popActiveSpan];
                [SentryPerformanceTracker.shared finishSpan:layoutSubViewId];

                [SentryPerformanceTracker.shared
                    measureSpanWithDescription:@"viewDidLayoutSubviews"
                                     operation:SENTRY_VIEWCONTROLLER_RENDERING_OPERATION
                                       inBlock:^{ SentrySWCallOriginal(); }];
                [SentryPerformanceTracker.shared popActiveSpan];
            }
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)didSelector);
}

#    pragma clang diagnostic pop
#endif
@end
