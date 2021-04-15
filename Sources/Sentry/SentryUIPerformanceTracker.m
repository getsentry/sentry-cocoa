#import "SentryUIPerformanceTracker.h"
#import "SentryHub.h"
#import "SentryLog.h"
#import "SentryPerformanceTracker.h"
#import "SentrySDK+Private.h"
#import "SentryScope.h"
#import "SentrySwizzle.h"
#import "UIViewControllerHelper.h"
#import <objc/runtime.h>

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>
#endif

static NSString *const SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID
    = @"SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID";

@implementation SentryUIPerformanceTracker

+ (void)start
{
    [SentryUIPerformanceTracker swizzleViewControllerInits];
}

+ (void)swizzleViewControllerInits
{
  #if SENTRY_HAS_UIKIT
    // SentrySwizzleInstanceMethod declaration shadows a local variable. The swizzling is working
    // fine and we accept this warning.
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wshadow"

    static const void *swizzleViewControllerInitWithCoder = &swizzleViewControllerInitWithCoder;
    SEL selector = NSSelectorFromString(@"initWithCoder:");
    SentrySwizzleInstanceMethod(UIViewController.class, selector, SentrySWReturnType(id),
        SentrySWArguments(NSCoder* coder), SentrySWReplacement({
            [SentryUIPerformanceTracker swizzleViewControllerSubClass:[self class]];
            return SentrySWCallOriginal(coder);
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, swizzleViewControllerInitWithCoder);

    static const void *swizzleViewControllerInitWithNib = &swizzleViewControllerInitWithInib;
    SEL selector = NSSelectorFromString(@"initWithNibName:bundle:");
    SentrySwizzleInstanceMethod(UIViewController.class, selector, SentrySWReturnType(id),
        SentrySWArguments(NSString* nibName, NSBundle* bundle), SentrySWReplacement({
            [SentryUIPerformanceTracker swizzleViewControllerSubClass:[self class]];
            return SentrySWCallOriginal(nibName, bundle);
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, swizzleViewControllerInitWithNib);  
#    pragma clang diagnostic pop
#else
    [SentryLog logWithMessage:@"NO UIKit -> [SentryBreadcrumbTracker "
                              @"swizzleViewDidAppear] does nothing."
                     andLevel:kSentryLevelDebug];
#endif  
}

+ (void)swizzleViewControllerSubClass:(Class) class
{
   [SentryUIPerformanceTracker swizzleLoadView:class];
   [SentryUIPerformanceTracker swizzleViewDidLoad:class];
   [SentryUIPerformanceTracker swizzleViewDidAppear:class]; 
}

+ (void)swizzleLoadView:(Class)class
{
#if SENTRY_HAS_UIKIT
    // SentrySwizzleInstanceMethod declaration shadows a local variable. The swizzling is working
    // fine and we accept this warning.
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wshadow"

    SEL selector = NSSelectorFromString(@"loadView");
    SentrySwizzleInstanceMethod(class, selector, SentrySWReturnType(void),
        SentrySWArguments(), SentrySWReplacement({
            NSString *name = [UIViewControllerHelper sanitizeViewControllerName:self];
            NSString *spanId = [SentryPerformanceTracker.shared startSpanWithName:name
                                                                        operation:@"ui.lifecycle"];

            objc_setAssociatedObject(self, &SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID, spanId,
                OBJC_ASSOCIATION_RETAIN_NONATOMIC);

            [SentryPerformanceTracker.shared pushActiveSpan:spanId];
            SentrySWCallOriginal();
            [SentryPerformanceTracker.shared popActiveSpan];
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, class);
#    pragma clang diagnostic pop
#else
    [SentryLog logWithMessage:@"NO UIKit -> [SentryBreadcrumbTracker "
                              @"swizzleViewDidAppear] does nothing."
                     andLevel:kSentryLevelDebug];
#endif
}

+ (void)swizzleViewDidLoad:(Class)class
{
#if SENTRY_HAS_UIKIT
    // SentrySwizzleInstanceMethod declaration shadows a local variable. The swizzling is working
    // fine and we accept this warning.
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wshadow"

    static const void *swizzleViewDidLoadKey = &swizzleViewDidLoadKey;
    SEL selector = NSSelectorFromString(@"viewDidLoad");
    SentrySwizzleInstanceMethod(class, selector, SentrySWReturnType(void),
        SentrySWArguments(), SentrySWReplacement({
            NSString *spanId
                = objc_getAssociatedObject(self, &SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID);

            if (spanId == nil) {
                SentrySWCallOriginal();
            } else {
                [SentryPerformanceTracker.shared pushActiveSpan:spanId];
                SentrySWCallOriginal();
                [SentryPerformanceTracker.shared popActiveSpan];
            }
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, class);
#    pragma clang diagnostic pop
#else
    [SentryLog logWithMessage:@"NO UIKit -> [SentryBreadcrumbTracker "
                              @"swizzleViewDidAppear] does nothing."
                     andLevel:kSentryLevelDebug];
#endif
}

+ (void)swizzleViewDidAppear:(Class)class
{
#if SENTRY_HAS_UIKIT
    // SentrySwizzleInstanceMethod declaration shadows a local variable. The swizzling is working
    // fine and we accept this warning.
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wshadow"

    static const void *swizzleViewDidAppearKey = &swizzleViewDidAppearKey;
    SEL selector = NSSelectorFromString(@"viewDidAppear:");
    SentrySwizzleInstanceMethod(class, selector, SentrySWReturnType(void),
        SentrySWArguments(BOOL animated), SentrySWReplacement({
            NSString *spanId
                = objc_getAssociatedObject(self, &SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID);

            if (spanId == nil) {
                SentrySWCallOriginal(animated);
            } else {
                [SentryPerformanceTracker.shared pushActiveSpan:spanId];
                SentrySWCallOriginal(animated);
                [SentryPerformanceTracker.shared popActiveSpan];
                [SentryPerformanceTracker.shared finishSpan:spanId];
            }
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, class);
#    pragma clang diagnostic pop
#else
    [SentryLog logWithMessage:@"NO UIKit -> [SentryBreadcrumbTracker "
                              @"swizzleViewDidAppear] does nothing."
                     andLevel:kSentryLevelDebug];
#endif
}

@end
