#import "SentryUIPerformanceTracker.h"
#import "SentryHub.h"
#import "SentryLog.h"
#import "SentryPerformanceTracker.h"
#import "SentrySDK+Private.h"
#import "SentryScope.h"
#import "SentrySpanId.h"
#import "SentrySwizzle.h"
#import "UIViewControllerHelper.h"
#import <objc/runtime.h>

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>
#endif

static NSString *const SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID
    = @"SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID";

static NSString *const SENTRY_UI_PERFORMANCE_TRACKER_LAYOUTSUBVIEW_SPAN_ID
    = @"SENTRY_UI_PERFORMANCE_TRACKER_LAYOUTSUBVIEW_SPAN_ID";

/**
 *Auxiliary class to store UIViewController performance monitoring spanid.
 */
@interface SentryViewControllerPerformanceSpans : NSObject

@property (nonatomic, strong) SentrySpanId *mainSpan;

@property (nonatomic, strong) SentrySpanId *layoutSubViewsSpan;

- (instancetype)initWithMainSpan:(SentrySpanId *)mainSpan;

@end

@implementation SentryViewControllerPerformanceSpans

- (instancetype)initWithMainSpan:(SentrySpanId *)mainSpan
{
    if (self = [super init]) {
        self.mainSpan = mainSpan;
    }
    return self;
}

@end

@interface
SentryUIPerformanceTracker ()
+ (NSMutableDictionary *)swizzeledViewControllers;
@end

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

/**
 *Global dictionary to store monitored UIViewControllers span ids.
 */
+ (NSMutableDictionary *)swizzeledViewControllers
{
    static NSMutableDictionary *_swizzeledViewControllers;
    if (_swizzeledViewControllers == nil)
        _swizzeledViewControllers = [[NSMutableDictionary alloc] init];

    return _swizzeledViewControllers;
}

/**
 * Swizzle the some init methods of the view controller,
 * so we can swizzle user view controller subclass on demand.
 */
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
            SentrySpanId *spanId =
                [SentryPerformanceTracker.shared startSpanWithName:name operation:@"navigation"];

            [SentryUIPerformanceTracker.swizzeledViewControllers
                setValue:[[SentryViewControllerPerformanceSpans alloc] initWithMainSpan:spanId]
                  forKey:self];

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
            SentryViewControllerPerformanceSpans *vcSpans =
                [SentryUIPerformanceTracker.swizzeledViewControllers objectForKey:self];
            SentrySpanId *spanId = vcSpans.mainSpan;

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

+ (void)swizzleViewWillAppear:(Class)class
{
#if SENTRY_HAS_UIKIT
    // SentrySwizzleInstanceMethod declaration shadows a local variable. The swizzling is working
    // fine and we accept this warning.
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wshadow"

    SEL selector = NSSelectorFromString(@"viewWillAppear:");
    SentrySwizzleInstanceMethod(class, selector, SentrySWReturnType(void),
        SentrySWArguments(BOOL animated), SentrySWReplacement({
            SentryViewControllerPerformanceSpans *vcSpans =
                [SentryUIPerformanceTracker.swizzeledViewControllers objectForKey:self];
            SentrySpanId *spanId = vcSpans.mainSpan;

            if (spanId == nil) {
                SentrySWCallOriginal(animated);
            } else {
                [SentryPerformanceTracker.shared pushActiveSpan:spanId];
                SentrySWCallOriginal(animated);
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
            SentryViewControllerPerformanceSpans *vcSpans =
                [SentryUIPerformanceTracker.swizzeledViewControllers objectForKey:self];
            SentrySpanId *spanId = vcSpans.mainSpan;

            if (spanId == nil) {
                SentrySWCallOriginal(animated);
            } else {
                [SentryPerformanceTracker.shared pushActiveSpan:spanId];
                SentrySWCallOriginal(animated);
                [SentryPerformanceTracker.shared popActiveSpan];
                [SentryPerformanceTracker.shared finishSpan:spanId];
            }

            // End of the UIViewControlker creation cycle. Remove the UIViewController from the
            // global dictionary.
            [SentryUIPerformanceTracker.swizzeledViewControllers removeObjectForKey:self];
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)selector);
#    pragma clang diagnostic pop
#endif
}

+ (void)swizzleViewLayoutSubViews:(Class)class
{
#if SENTRY_HAS_UIKIT
    // SentrySwizzleInstanceMethod declaration shadows a local variable. The swizzling is working
    // fine and we accept this warning.
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wshadow"

    SEL willSelector = NSSelectorFromString(@"viewWillLayoutSubviews");
    SentrySwizzleInstanceMethod(class, willSelector, SentrySWReturnType(void), SentrySWArguments(),
        SentrySWReplacement({
            SentryViewControllerPerformanceSpans *vcSpans =
                [SentryUIPerformanceTracker.swizzeledViewControllers objectForKey:self];
            SentrySpanId *spanId = vcSpans.mainSpan;

            if (spanId == nil || ![SentryPerformanceTracker.shared isSpanAlive:spanId]) {
                SentrySWCallOriginal();
            } else {
                [SentryPerformanceTracker.shared pushActiveSpan:spanId];
                SentrySpanId *layoutSubViewId =
                    [SentryPerformanceTracker.shared startSpanWithName:@"layoutSubViews"
                                                             operation:@"navigation"];

                vcSpans.layoutSubViewsSpan = layoutSubViewId;

                SentrySWCallOriginal();
                [SentryPerformanceTracker.shared popActiveSpan];
            }
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)willSelector);

    SEL didSelector = NSSelectorFromString(@"viewDidLayoutSubviews");
    SentrySwizzleInstanceMethod(class, didSelector, SentrySWReturnType(void), SentrySWArguments(),
        SentrySWReplacement({
            SentryViewControllerPerformanceSpans *vcSpans =
                [SentryUIPerformanceTracker.swizzeledViewControllers objectForKey:self];
            SentrySpanId *spanId = vcSpans.mainSpan;

            if (spanId == nil || ![SentryPerformanceTracker.shared isSpanAlive:spanId]) {
                SentrySWCallOriginal();
            } else {
                [SentryPerformanceTracker.shared pushActiveSpan:spanId];
                SentrySWCallOriginal();

                SentrySpanId *layoutSubViewId = vcSpans.layoutSubViewsSpan;
                [SentryPerformanceTracker.shared finishSpan:layoutSubViewId];
                [SentryPerformanceTracker.shared popActiveSpan];
            }
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)didSelector);
#    pragma clang diagnostic pop
#endif
}

@end
