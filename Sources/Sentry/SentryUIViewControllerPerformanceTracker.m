#import "SentryUIViewControllerPerformanceTracker.h"
#import "SentryHub.h"
#import "SentryLog.h"
#import "SentryPerformanceTracker.h"
#import "SentrySDK+Private.h"
#import "SentryScope.h"
#import "SentrySpanId.h"
#import "SentrySwizzle.h"
#import "SentryUIViewControllerSanitizer.h"
#import <objc/runtime.h>

static NSString *const SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID
    = @"SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID";

static NSString *const SENTRY_UI_PERFORMANCE_TRACKER_LAYOUTSUBVIEW_SPAN_ID
    = @"SENTRY_UI_PERFORMANCE_TRACKER_LAYOUTSUBVIEW_SPAN_ID";

@interface
SentryUIViewControllerPerformanceTracker ()

@property (nonatomic, strong) SentryPerformanceTracker *tracker;

@end

@implementation SentryUIViewControllerPerformanceTracker

+ (instancetype)shared
{
    static SentryUIViewControllerPerformanceTracker *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (instancetype)init
{
    if (self = [super init]) {
        self.tracker = SentryPerformanceTracker.shared;
    }
    return self;
}

#if SENTRY_HAS_UIKIT

- (void)viewControllerLoadView:(UIViewController *)controller
              callbackToOrigin:(void (^)(void))callback
{
    NSString *name = [SentryUIViewControllerSanitizer sanitizeViewControllerName:controller];
    SentrySpanId *spanId =
        [self.tracker startSpanWithName:name operation:SENTRY_VIEWCONTROLLER_RENDERING_OPERATION];

    // use the target itself to store the spanId to avoid using a global mapper.
    objc_setAssociatedObject(controller, &SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID, spanId,
        OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    [self measurePerformance:@"loadView" target:controller blockToMeasure:callback];
}

- (void)viewControllerViewDidLoad:(UIViewController *)controller
                 callbackToOrigin:(void (^)(void))callback
{
    [self measurePerformance:@"viewDidLoad" target:controller blockToMeasure:callback];
}

- (void)viewControllerViewWillAppear:(UIViewController *)controller
                    callbackToOrigin:(void (^)(void))callback
{
    [self measurePerformance:@"viewWillAppear" target:controller blockToMeasure:callback];
}

- (void)viewControllerViewDidAppear:(UIViewController *)controller
                   callbackToOrigin:(void (^)(void))callback
{
    [self measurePerformance:@"viewDidAppear" target:controller blockToMeasure:callback];

    SentrySpanId *spanId
        = objc_getAssociatedObject(controller, &SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID);

    if (spanId != nil) {
        // if we still tracking this UIViewController, finishes the transaction and remove
        // associated span id.
        [self.tracker finishSpan:spanId];
        objc_setAssociatedObject(controller, &SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID, nil,
            OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

- (void)viewControllerViewWillLayoutSubViews:(UIViewController *)controller
                            callbackToOrigin:(void (^)(void))callback
{
    SentrySpanId *spanId
        = objc_getAssociatedObject(controller, &SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID);

    if (spanId == nil || ![self.tracker isSpanAlive:spanId]) {
        // We are no longer tracking this UIViewController, just call the base method.
        callback();
    } else {
        [self.tracker pushActiveSpan:spanId];
        [self.tracker measureSpanWithDescription:@"viewWillLayoutSubviews"
                                       operation:SENTRY_VIEWCONTROLLER_RENDERING_OPERATION
                                         inBlock:callback];

        SentrySpanId *layoutSubViewId =
            [self.tracker startSpanWithName:@"layoutSubViews"
                                  operation:SENTRY_VIEWCONTROLLER_RENDERING_OPERATION];

        objc_setAssociatedObject(controller, &SENTRY_UI_PERFORMANCE_TRACKER_LAYOUTSUBVIEW_SPAN_ID,
            layoutSubViewId, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        [self.tracker pushActiveSpan:layoutSubViewId];
    }
}

- (void)viewControllerViewDidLayoutSubViews:(UIViewController *)controller
                           callbackToOrigin:(void (^)(void))callback
{
    SentrySpanId *spanId
        = objc_getAssociatedObject(controller, &SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID);

    if (spanId == nil || ![self.tracker isSpanAlive:spanId]) {
        // We are no longer tracking this UIViewController, just call the base method.
        callback();
    } else {
        SentrySpanId *layoutSubViewId = objc_getAssociatedObject(
            controller, &SENTRY_UI_PERFORMANCE_TRACKER_LAYOUTSUBVIEW_SPAN_ID);
        [self.tracker popActiveSpan];
        [self.tracker finishSpan:layoutSubViewId];

        [self.tracker measureSpanWithDescription:@"viewDidLayoutSubviews"
                                       operation:SENTRY_VIEWCONTROLLER_RENDERING_OPERATION
                                         inBlock:callback];
        [self.tracker popActiveSpan];
        objc_setAssociatedObject(controller, &SENTRY_UI_PERFORMANCE_TRACKER_LAYOUTSUBVIEW_SPAN_ID,
            nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

- (void)measurePerformance:(NSString *)description
                    target:(UIViewController *)viewController
            blockToMeasure:(void (^)(void))callback
{
    SentrySpanId *spanId
        = objc_getAssociatedObject(viewController, &SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID);

    if (spanId == nil) {
        // We are no longer tracking this UIViewController, just call the base method.
        callback();
    } else {
        [self.tracker measureSpanWithDescription:description
                                       operation:SENTRY_VIEWCONTROLLER_RENDERING_OPERATION
                                    parentSpanId:spanId
                                         inBlock:callback];
    }
}
#endif

@end
