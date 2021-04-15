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
    
#if SENTRY_HAS_UIKIT
    [SentryUIPerformanceTracker swizzleViewControllerInits];
#else
    [SentryLog logWithMessage:@"NO UIKit -> [SentryUIPerformanceTracker "
                              @"start] does nothing."
                     andLevel:kSentryLevelDebug];
#endif
}

+ (void)swizzleViewControllerInits
{
#if SENTRY_HAS_UIKIT
    // SentrySwizzleInstanceMethod declaration shadows a local variable. The swizzling is working
    // fine and we accept this warning.
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wshadow"

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
#    pragma clang diagnostic pop
#endif
}

+ (void)swizzleViewControllerSubClass:(Class)class
{
#if SENTRY_HAS_UIKIT
    static const char* appImage = nil;
    if (appImage == nil) {
        if ([UIApplication respondsToSelector:@selector(sharedApplication)]) {
            UIApplication* app = [UIApplication performSelector:@selector(sharedApplication)];
            appImage = class_getImageName(app.delegate.class);
        }
    }
    if (strcmp(appImage, class_getImageName(class)) != 0) return;
    
    [SentryUIPerformanceTracker swizzleLoadView:class];
    [SentryUIPerformanceTracker swizzleViewDidLoad:class];
    [SentryUIPerformanceTracker swizzleViewDidAppear:class];
#endif
}

+ (void)swizzleLoadView:(Class)class
{
#if SENTRY_HAS_UIKIT
    // SentrySwizzleInstanceMethod declaration shadows a local variable. The swizzling is working
    // fine and we accept this warning.
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wshadow"

    SEL selector = NSSelectorFromString(@"loadView");
    SentrySwizzleInstanceMethod(class, selector, SentrySWReturnType(void), SentrySWArguments(),
        SentrySWReplacement({
            NSString *name = [UIViewControllerHelper sanitizeViewControllerName:self];
            NSString *spanId = [SentryPerformanceTracker.shared startSpanWithName:name
                                                                        operation:@"ui.lifecycle"];

            objc_setAssociatedObject(self, &SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID, spanId,
                OBJC_ASSOCIATION_RETAIN_NONATOMIC);

            [SentryPerformanceTracker.shared pushActiveSpan:spanId];
            SentrySWCallOriginal();
            [SentryPerformanceTracker.shared popActiveSpan];
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)selector);
#    pragma clang diagnostic pop
#endif
}

+ (void)swizzleViewDidLoad:(Class)class
{
#if SENTRY_HAS_UIKIT
    // SentrySwizzleInstanceMethod declaration shadows a local variable. The swizzling is working
    // fine and we accept this warning.
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wshadow"

    SEL selector = NSSelectorFromString(@"viewDidLoad");
    SentrySwizzleInstanceMethod(class, selector, SentrySWReturnType(void), SentrySWArguments(),
        SentrySWReplacement({
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
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)selector);
#    pragma clang diagnostic pop
#endif
}

+ (void)swizzleViewDidAppear:(Class)class
{
#if SENTRY_HAS_UIKIT
    // SentrySwizzleInstanceMethod declaration shadows a local variable. The swizzling is working
    // fine and we accept this warning.
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wshadow"

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
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)selector);
#    pragma clang diagnostic pop
#endif
}

@end
